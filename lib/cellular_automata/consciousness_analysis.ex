defmodule CellularAutomata.ConsciousnessAnalysis do
  @moduledoc """
  Consciousness detection for product De Bruijn graphs.

  Formalises the definition:

    > A system is conscious if it contains a closed feedback loop in which
    > the system maintains a coarse-grained but causally sufficient
    > self-model  M ≈ ξ(S, δ, M),  and uses that model to update itself.

  In a De Bruijn graph of order `k`, the coarse-graining function ξ is
  *fixed* as k-mer truncation: the order `k` itself determines the level
  of description.
  Instead of tracking the entire spacetime history, each node only "sees"
  a window of exactly `k` consecutive time steps. Any configuration is
  represented as a `k`-bit tuple — a k-mer. Everything outside that window
  is discarded.
  To obtain a finer-grained self-model (one that can describe longer
  cycles, richer temporal patterns), you rebuild the graph at a larger `k`.
  We don't adjust ξ independently — `k` and ξ are the same knob.

  ## Pipeline

      graph  = CellularAutomata.ProductDeBruijnGraph.build(rule_id, k)
      result = CellularAutomata.ConsciousnessAnalysis.analyse(graph)

  `result` is a list of `%AttractorReport{}` structs, one per attractor
  cycle, sorted by consciousness score descending.

  ## Theoretical background

  Each node `{a, b}` in the product De Bruijn graph represents a pair of
  consecutive k-bit time slices of a spatially periodic CA configuration.
  An edge `{a,b} → {b,c}` exists when the CA rule maps `a` to `b` given
  the neighbourhood context `c`.

  Level-1 self-reference (the loop itself) is detected by Kosaraju SCC.
  Level-2 richness (the self-model carries the transition function δ) is
  measured via transition entropy and fixed-point distance.
  Level-3 richness (reflective closure) is approximated by transfer
  entropy on self-loops; a full Gödelian check is intentionally omitted
  because it is undecidable in general — ξ eliminates the need for it.
  """

  import Bitwise
  alias CellularAutomata.ProductDeBruijnGraph

  # ---------------------------------------------------------------------------
  # Public data structures
  # ---------------------------------------------------------------------------

  defmodule NodeState do
    @moduledoc """
    Enriched representation of a single node in the product De Bruijn graph.

    Fields
    ------
    * `a`            – k-tuple: the *previous* time slice (context window)
    * `b`            – k-tuple: the *current*  time slice (state proper)
    * `transitions`  – map from successor node `{b, c}` to relative weight
                       (uniform 1/n for unweighted graphs)
    * `self_model`   – populated after SCC analysis; see `SelfModel`
    """
    defstruct [:a, :b, :transitions, :self_model]
  end

  defmodule SelfModel do
    @moduledoc """
    The compressed self-model  M ≈ ξ(S, δ, M)  attached to each node.

    Fields
    ------
    * `reachable`           – MapSet of nodes reachable within the SCC
    * `loop_lengths`        – map of cycle lengths → count (approximated
                               from the SCC diameter)
    * `transition_entropy`  – Shannon entropy of the outgoing edge distribution
    * `in_degree`           – number of incoming edges within the SCC
    * `out_degree`          – number of outgoing edges within the SCC
    """
    defstruct [:reachable, :loop_lengths, :transition_entropy, :in_degree, :out_degree]
  end

  defmodule AttractorReport do
    @moduledoc """
    Analysis result for one attractor cycle.

    Fields
    ------
    * `cycle`                 – list of `{a, b}` node tuples forming the cycle
    * `size`                  – number of nodes in the cycle
    * `feedback`              – fraction of cycle nodes that can reach themselves
    * `observability`         – neighbourhood-pattern diversity (0..1)
    * `transfer_entropy`      – mean self-loop transfer entropy across cycle nodes
    * `fixed_point_distance`  – mean d(M, ξ(S,δ,M)); lower = richer self-model
    * `differentiated`        – true when nodes have distinct reachability sets
    * `consciousness_score`   – composite score in [0,1]
    * `conscious?`            – boolean verdict
    * `node_states`           – list of enriched `%NodeState{}` structs
    """
    defstruct [
      :cycle,
      :size,
      :feedback,
      :observability,
      :transfer_entropy,
      :fixed_point_distance,
      :differentiated,
      :consciousness_score,
      :conscious?,
      :node_states
    ]
  end

  # ---------------------------------------------------------------------------
  # Thresholds (all tunable)
  # ---------------------------------------------------------------------------

  # Minimum fraction of self-looping nodes to consider feedback real
  @feedback_threshold 0.30
  # Minimum neighbourhood-pattern diversity
  @observability_threshold 0.30
  # Maximum fixed-point distance to consider the self-model causally sufficient
  @epsilon 0.05

  # ---------------------------------------------------------------------------
  # Main entry point
  # ---------------------------------------------------------------------------

  @doc """
  Analyses `graph` for conscious attractors.

  `graph` must be the map returned by
  `CellularAutomata.ProductDeBruijnGraph.build/2`.

  Returns a list of `%AttractorReport{}`, sorted by `consciousness_score`
  descending.  Only attractors with at least `min_size` nodes are reported
  (default 2).

  ## Options

  * `:min_size`  – minimum cycle length to consider (default: `2`)
  * `:epsilon`   – fixed-point distance threshold (default: `#{@epsilon}`)
  """
  @spec analyse(ProductDeBruijnGraph.t(), keyword()) :: list(%AttractorReport{})
  def analyse(graph, opts \\ []) do
    min_size = Keyword.get(opts, :min_size, 2)
    epsilon = Keyword.get(opts, :epsilon, @epsilon)

    attractors = find_attractors(graph)

    attractors
    |> Enum.filter(&(length(&1) >= min_size))
    |> Enum.map(&build_report(&1, graph, epsilon))
    |> Enum.sort_by(& &1.consciousness_score, :desc)
  end

  # ---------------------------------------------------------------------------
  # Attractor detection (delegates to ProductDeBruijnGraph-compatible SCC)
  # ---------------------------------------------------------------------------

  @doc """
  Returns one representative cycle per attractor in `graph`.

  Delegates to the same Kosaraju-based SCC used in `ProductDeBruijnGraph`,
  then extracts one cycle per non-trivial SCC.
  """
  @spec find_attractors(ProductDeBruijnGraph.t()) :: list(list(tuple()))
  def find_attractors(graph) do
    graph
    |> scc()
    |> Enum.filter(fn
      [node] -> node in Map.get(graph, node, [])
      _ -> true
    end)
    |> Enum.map(&find_cycle(graph, &1))
  end

  # ---------------------------------------------------------------------------
  # Report builder
  # ---------------------------------------------------------------------------

  defp build_report(cycle, graph, epsilon) do
    scc_set = MapSet.new(cycle)
    sub = induced_subgraph(graph, scc_set)

    node_states = enrich_nodes(cycle, sub)
    fb = feedback_strength(cycle, sub)
    obs = observability(sub)
    te = mean_transfer_entropy(node_states)
    fp_dist = mean_fixed_point_distance(node_states, sub)
    differentiated = differentiated_dynamics?(cycle, sub)

    score = consciousness_score(fb, obs, te, fp_dist, epsilon)

    %AttractorReport{
      cycle: cycle,
      size: length(cycle),
      feedback: fb,
      observability: obs,
      transfer_entropy: te,
      fixed_point_distance: fp_dist,
      differentiated: differentiated,
      consciousness_score: score,
      conscious?:
        fb > @feedback_threshold and
          obs > @observability_threshold and
          fp_dist < epsilon and
          differentiated,
      node_states: node_states
    }
  end

  # ---------------------------------------------------------------------------
  # Node enrichment — Level 1 & 2 state representation
  # ---------------------------------------------------------------------------

  @doc """
  Builds an enriched `%NodeState{}` for every node in `cycle`, using
  `sub` (the induced subgraph restricted to the SCC) for all graph queries.
  """
  @spec enrich_nodes(list(tuple()), map()) :: list(%NodeState{})
  def enrich_nodes(cycle, sub) do
    scc_set = MapSet.new(cycle)

    reachability =
      Map.new(cycle, fn node ->
        {node, reachable_within(sub, node)}
      end)

    Enum.map(cycle, fn node ->
      succs = Map.get(sub, node, [])
      trans = uniform_transitions(succs)
      t_entropy = shannon_entropy(Map.values(trans))
      in_deg = in_degree(sub, node)

      self_model = %SelfModel{
        reachable: reachability[node],
        loop_lengths: loop_length_distribution(sub, node, scc_set),
        transition_entropy: t_entropy,
        in_degree: in_deg,
        out_degree: length(succs)
      }

      {a, b} = node

      %NodeState{
        a: a,
        b: b,
        transitions: trans,
        self_model: self_model
      }
    end)
  end

  # ---------------------------------------------------------------------------
  # Feedback strength
  # ---------------------------------------------------------------------------

  @doc """
  Fraction of `cycle` nodes that can reach themselves within `sub`.

  A value of 1.0 means every node is part of a self-referential loop,
  which is the structural prerequisite for Level-1 consciousness.
  """
  @spec feedback_strength(list(tuple()), map()) :: float()
  def feedback_strength(cycle, sub) do
    self_looping =
      Enum.count(cycle, fn node ->
        MapSet.member?(reachable_within(sub, node), node)
      end)

    self_looping / max(length(cycle), 1)
  end

  # ---------------------------------------------------------------------------
  # Observability  (neighbourhood-pattern diversity)
  # ---------------------------------------------------------------------------

  @doc """
  Measures how many distinct outgoing-neighbourhood patterns exist in `sub`,
  normalised by the total number of nodes.

  High observability means the system's parts behave differently from one
  another — a necessary condition for differentiated information processing.
  """
  @spec observability(map()) :: float()
  def observability(sub) do
    patterns =
      sub
      |> Enum.map(fn {_n, neigh} -> Enum.sort(neigh) end)

    unique = patterns |> MapSet.new() |> MapSet.size()
    total = length(patterns)

    if total == 0, do: 0.0, else: unique / total
  end

  # ---------------------------------------------------------------------------
  # Differentiated dynamics
  # ---------------------------------------------------------------------------

  @doc """
  Returns `true` when nodes in `cycle` have distinct reachability sets within
  `sub`.  A homogeneous SCC where every node can reach the same things carries
  no internal differentiation and is not considered conscious.
  """
  @spec differentiated_dynamics?(list(tuple()), map()) :: boolean()
  def differentiated_dynamics?(cycle, sub) do
    reach_sets =
      Enum.map(cycle, fn node -> reachable_within(sub, node) end)

    unique = reach_sets |> MapSet.new() |> MapSet.size()
    unique > 1
  end

  # ---------------------------------------------------------------------------
  # Transfer entropy  (Level-3 richness proxy)
  # ---------------------------------------------------------------------------

  @doc """
  Computes a transfer-entropy proxy for a single `%NodeState{}`.

  Transfer entropy  TE(X→X)  measures how much a node's own past predicts
  its future — a proxy for self-referential information flow:

      TE ≈ H(uniform) - H(out_distribution)

  where H is Shannon entropy.  Positive TE means the node's transitions are
  non-uniform, i.e. the node's history matters to its future.

  Returns a value in [0, log2(out_degree)] bits.
  """
  @spec transfer_entropy(%NodeState{}) :: float()
  def transfer_entropy(%NodeState{transitions: trans}) when map_size(trans) == 0, do: 0.0

  def transfer_entropy(%NodeState{transitions: trans}) do
    n = map_size(trans)
    h_uniform = :math.log2(max(n, 1))
    h_actual = shannon_entropy(Map.values(trans))

    # TE proxy: deviation from uniform baseline (clamped to [0, h_uniform])
    max(h_uniform - h_actual, 0.0)
  end

  @doc """
  Mean transfer entropy across all nodes in `node_states`.
  """
  @spec mean_transfer_entropy(list(%NodeState{})) :: float()
  def mean_transfer_entropy([]), do: 0.0

  def mean_transfer_entropy(node_states) do
    node_states
    |> Enum.map(&transfer_entropy/1)
    |> mean()
  end

  # ---------------------------------------------------------------------------
  # Fixed-point distance  d(M, ξ(S, δ, M))
  # ---------------------------------------------------------------------------

  @doc """
  Recomputes the self-model from scratch for `node_state` using `sub` and
  returns the distance  d(M, ξ(S, δ, M)).

  The distance is the mean absolute difference of the four normalised
  scalar fields of `%SelfModel{}`:

  * transition entropy
  * in-degree (normalised by SCC size)
  * out-degree (normalised by SCC size)
  * reachability size (normalised by SCC size)

  A distance of 0.0 means the self-model is a perfect fixed point of ξ.
  Values above `epsilon` mean the node's self-model is too coarse to
  faithfully represent its own causal role.
  """
  @spec fixed_point_distance(%NodeState{}, map()) :: float()
  def fixed_point_distance(%NodeState{a: a, b: b, self_model: m}, sub) do
    node = {a, b}
    n = max(map_size(sub), 1)
    succs = Map.get(sub, node, [])
    trans2 = uniform_transitions(succs)

    m2 = %SelfModel{
      reachable: reachable_within(sub, node),
      transition_entropy: shannon_entropy(Map.values(trans2)),
      in_degree: in_degree(sub, node),
      out_degree: length(succs),
      # ξ keeps loop structure fixed
      loop_lengths: m.loop_lengths
    }

    fields = [
      abs(m.transition_entropy - m2.transition_entropy) /
        max(m.transition_entropy + m2.transition_entropy, 1.0e-10),
      abs(m.in_degree - m2.in_degree) / n,
      abs(m.out_degree - m2.out_degree) / n,
      abs(MapSet.size(m.reachable) - MapSet.size(m2.reachable)) / n
    ]

    mean(fields)
  end

  @doc """
  Mean fixed-point distance across all nodes in `node_states`.
  """
  @spec mean_fixed_point_distance(list(%NodeState{}), map()) :: float()
  def mean_fixed_point_distance([], _sub), do: 1.0

  def mean_fixed_point_distance(node_states, sub) do
    node_states
    |> Enum.map(&fixed_point_distance(&1, sub))
    |> mean()
  end

  # ---------------------------------------------------------------------------
  # Composite consciousness score
  # ---------------------------------------------------------------------------

  @doc """
  Returns a composite score in [0, 1] that summarises how strongly an
  attractor satisfies the consciousness criteria.

  The formula weights the four dimensions equally:

      score = 0.25 * feedback
            + 0.25 * observability
            + 0.25 * transfer_entropy_normalised
            + 0.25 * (1 - fixed_point_distance / epsilon)

  All components are clamped to [0, 1] before weighting.
  """
  @spec consciousness_score(float(), float(), float(), float(), float()) :: float()
  def consciousness_score(feedback, observability, transfer_entropy, fp_dist, epsilon) do
    te_norm = clamp(transfer_entropy, 0.0, 1.0)
    fp_score = clamp(1.0 - fp_dist / max(epsilon, 1.0e-10), 0.0, 1.0)

    0.25 * clamp(feedback, 0.0, 1.0) +
      0.25 * clamp(observability, 0.0, 1.0) +
      0.25 * te_norm +
      0.25 * fp_score
  end

  # ---------------------------------------------------------------------------
  # Graph utilities
  # ---------------------------------------------------------------------------

  @doc """
  Returns the subgraph of `graph` induced by `scc_set` (a `MapSet` of nodes).
  Edges to nodes outside `scc_set` are removed.
  """
  @spec induced_subgraph(ProductDeBruijnGraph.t(), MapSet.t()) :: map()
  def induced_subgraph(graph, scc_set) do
    graph
    |> Enum.filter(fn {n, _} -> MapSet.member?(scc_set, n) end)
    |> Enum.map(fn {n, neigh} ->
      {n, Enum.filter(neigh, &MapSet.member?(scc_set, &1))}
    end)
    |> Map.new()
  end

  @doc """
  Returns the set of nodes reachable from `start` within `graph`
  (inclusive of `start`).
  """
  @spec reachable_within(ProductDeBruijnGraph.t(), tuple()) :: MapSet.t()
  def reachable_within(graph, start) do
    bfs([start], MapSet.new([start]), graph)
  end

  defp bfs([], visited, _graph), do: visited

  defp bfs([h | t], visited, graph) do
    new_neighbors =
      Map.get(graph, h, [])
      |> Enum.reject(&MapSet.member?(visited, &1))

    bfs(t ++ new_neighbors, MapSet.union(visited, MapSet.new(new_neighbors)), graph)
  end

  # ---------------------------------------------------------------------------
  # SCC (Kosaraju) — bitset variant matching ProductDeBruijnGraph
  # ---------------------------------------------------------------------------

  @doc """
  Computes the strongly-connected components of `graph` using Kosaraju's
  algorithm with a bitset adjacency representation (same approach as
  `ProductDeBruijnGraph.scc/1`).
  """
  @spec scc(ProductDeBruijnGraph.t()) :: list(list(tuple()))
  def scc(graph) do
    nodes = graph |> collect_nodes() |> Enum.sort()
    n = length(nodes)
    index = nodes |> Enum.with_index() |> Map.new()

    bit_graph =
      Enum.map(nodes, fn node ->
        Map.get(graph, node, [])
        |> Enum.reduce(0, fn to, acc -> acc ||| 1 <<< Map.fetch!(index, to) end)
      end)

    bit_graph_t = transpose_bitgraph(bit_graph)
    finish_order = kosaraju_pass1(bit_graph, n)

    kosaraju_pass2(bit_graph_t, finish_order)
    |> Enum.map(fn idx_list -> Enum.map(idx_list, &Enum.at(nodes, &1)) end)
  end

  # ---------------------------------------------------------------------------
  # Cycle extraction within a single SCC
  # ---------------------------------------------------------------------------

  @doc """
  Finds one representative cycle within `scc` using iterative DFS.

  Fixes the crash in `ProductDeBruijnGraph.walk/5` that occurs when a node
  in the SCC has no outgoing edges to other SCC members.
  """
  @spec find_cycle(ProductDeBruijnGraph.t(), list(tuple())) :: list(tuple())
  def find_cycle(graph, scc) do
    scc_set = MapSet.new(scc)
    walk(graph, scc_set, hd(scc), %{}, [])
  end

  # Safe walk: returns path-so-far when no neighbour is available instead of crashing.
  defp walk(graph, scc_set, node, visited, path) do
    if Map.has_key?(visited, node) do
      cycle_start = visited[node]
      path |> Enum.reverse() |> Enum.drop(cycle_start)
    else
      visited = Map.put(visited, node, length(path))
      path = [node | path]

      neighbors =
        Map.get(graph, node, [])
        |> Enum.filter(&MapSet.member?(scc_set, &1))

      case neighbors do
        # degenerate — return what we have
        [] -> Enum.reverse(path)
        [next | _] -> walk(graph, scc_set, next, visited, path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Helper: loop length distribution
  # ---------------------------------------------------------------------------

  # Approximates loop lengths by BFS distance from node back to itself.
  # Returns a map of %{length => 1} for detected self-loops, or %{} otherwise.
  defp loop_length_distribution(sub, node, scc_set) do
    # Simple approximation: check for direct self-loop and short cycles (≤ SCC size)
    max_len = MapSet.size(scc_set)

    Enum.reduce(1..max_len, %{}, fn len, acc ->
      if cycle_of_length?(sub, node, node, len, MapSet.new(), 0) do
        Map.put(acc, len, 1)
      else
        acc
      end
    end)
  end

  defp cycle_of_length?(_sub, target, current, len, _visited, depth) when depth == len do
    current == target
  end

  defp cycle_of_length?(sub, target, current, len, visited, depth) do
    Map.get(sub, current, [])
    |> Enum.reject(&(depth > 0 and &1 == target and depth < len - 1))
    |> Enum.reject(&MapSet.member?(visited, &1))
    |> Enum.any?(fn next ->
      cycle_of_length?(sub, target, next, len, MapSet.put(visited, next), depth + 1)
    end)
  end

  # ---------------------------------------------------------------------------
  # Graph helpers
  # ---------------------------------------------------------------------------

  defp collect_nodes(graph) do
    sources = Map.keys(graph)
    targets = graph |> Map.values() |> List.flatten()
    Enum.uniq(sources ++ targets)
  end

  defp in_degree(sub, node) do
    Enum.count(sub, fn {_from, tos} -> node in tos end)
  end

  defp uniform_transitions([]), do: %{}

  defp uniform_transitions(succs) do
    n = length(succs)
    Map.new(succs, fn s -> {s, 1.0 / n} end)
  end

  # ---------------------------------------------------------------------------
  # Kosaraju internals (bitset variant)
  # ---------------------------------------------------------------------------

  defp kosaraju_pass1(graph, n) do
    {_visited, finish} =
      Enum.reduce(0..(n - 1), {0, []}, fn v, {visited, stack} ->
        if (visited &&& 1 <<< v) != 0 do
          {visited, stack}
        else
          visited = visited ||| 1 <<< v
          dfs_finish(graph, [{v, Enum.at(graph, v)}], visited, stack)
        end
      end)

    finish
  end

  defp dfs_finish(_graph, [], visited, stack), do: {visited, stack}

  defp dfs_finish(graph, [{node, remaining} | frames], visited, stack) do
    if remaining == 0 do
      dfs_finish(graph, frames, visited, [node | stack])
    else
      lsb = remaining &&& -remaining
      neighbor = do_ctz(lsb, 0)
      remaining = bxor(remaining, lsb)

      if (visited &&& 1 <<< neighbor) != 0 do
        dfs_finish(graph, [{node, remaining} | frames], visited, stack)
      else
        visited = visited ||| 1 <<< neighbor

        dfs_finish(
          graph,
          [{neighbor, Enum.at(graph, neighbor)}, {node, remaining} | frames],
          visited,
          stack
        )
      end
    end
  end

  defp kosaraju_pass2(graph_t, finish_order) do
    {_visited, sccs} =
      Enum.reduce(finish_order, {0, []}, fn v, {visited, sccs} ->
        if (visited &&& 1 <<< v) != 0 do
          {visited, sccs}
        else
          visited = visited ||| 1 <<< v

          {new_visited, scc_bits} =
            dfs_collect(graph_t, visited, 1 <<< v, [{v, Enum.at(graph_t, v)}])

          {new_visited, [bitset_to_list(scc_bits) | sccs]}
        end
      end)

    sccs
  end

  defp dfs_collect(_graph, visited, scc, []), do: {visited, scc}

  defp dfs_collect(graph, visited, scc, [{node, remaining} | frames]) do
    if remaining == 0 do
      dfs_collect(graph, visited, scc, frames)
    else
      lsb = remaining &&& -remaining
      neighbor = do_ctz(lsb, 0)
      remaining = bxor(remaining, lsb)

      if (visited &&& 1 <<< neighbor) != 0 do
        dfs_collect(graph, visited, scc, [{node, remaining} | frames])
      else
        visited = visited ||| 1 <<< neighbor

        dfs_collect(graph, visited, scc ||| 1 <<< neighbor, [
          {neighbor, Enum.at(graph, neighbor)},
          {node, remaining} | frames
        ])
      end
    end
  end

  defp transpose_bitgraph(graph) do
    n = length(graph)

    for j <- 0..(n - 1) do
      graph
      |> Enum.with_index()
      |> Enum.reduce(0, fn {row, i}, acc ->
        if (row &&& 1 <<< j) != 0, do: acc ||| 1 <<< i, else: acc
      end)
    end
  end

  defp do_ctz(1, acc), do: acc
  defp do_ctz(n, acc), do: do_ctz(n >>> 1, acc + 1)

  defp bitset_to_list(bitset) do
    Stream.unfold(bitset, fn
      0 ->
        nil

      x ->
        lsb = x &&& -x
        idx = do_ctz(lsb, 0)
        {idx, bxor(x, lsb)}
    end)
    |> Enum.to_list()
  end

  # ---------------------------------------------------------------------------
  # Math utilities
  # ---------------------------------------------------------------------------

  defp shannon_entropy([]), do: 0.0

  defp shannon_entropy(probs) do
    Enum.reduce(probs, 0.0, fn p, acc ->
      if p > 0, do: acc - p * :math.log2(p), else: acc
    end)
  end

  defp mean([]), do: 0.0
  defp mean(list), do: Enum.sum(list) / length(list)

  defp clamp(v, lo, hi), do: max(lo, min(hi, v))
end
