defmodule CellularAutomata.ProductDeBruijnGraph do
  @moduledoc """
  Spatio-temporal cycle detection using the product De Bruijn graph.
  This allows detecting period-k attractors directly, without enumerating $$2^N$$
  global states.
  """
  import Bitwise

  # Colour palette used to distinguish different attractor cycles across both
  # the graph diagram and the spacetime grid.
  @cycle_colors ~w[#e84040 #4064e8 #28a828 #e87820 #9428c8 #e82896 #28a8c8 #c8c828]

  @doc """
  Builds the product De Bruijn graph for an elementary cellular automaton identified by
  `rule_id` and temporal period `k`.

  Each node is a pair `{a, b}` of `k`-bit vectors representing two consecutive time steps
  of a spatially periodic configuration. An edge `{a, b} → {b, c}` exists when the
  transition from `a` to `b` is consistent with the rule applied to the neighbourhood
  defined by `a`, `b`, and `c`.

  Returns a map from each source node to its list of target nodes.
  """
  @spec build(map(), pos_integer) :: map()
  def build(rule_id, k) do
    bits = all_bit_vectors(k)

    nodes =
      for a <- bits, b <- bits do
        {a, b}
      end

    Enum.reduce(nodes, %{}, fn node, g ->
      edges = outgoing_edges(node, rule_id, k)

      if edges == [] do
        g
      else
        Map.put(g, node, edges)
      end
    end)
  end

  @doc """
  Finds all simple cycles in `graph` using depth-first search.

  Each cycle is returned in canonical form: rotated so that its lexicographically
  smallest node comes first, ensuring each distinct cycle appears exactly once
  regardless of which node the search started from.

  Returns a list of cycles, where each cycle is a list of nodes.
  """
  @spec find_cycles(map()) :: list(list(tuple()))
  def find_cycles(graph) do
    graph
    |> Map.keys()
    |> Enum.flat_map(fn node -> dfs(graph, node, node, [node], MapSet.new([node])) end)
    |> Enum.map(&canonicalize_cycle/1)
    |> Enum.uniq()
  end

  @doc """
  Finds one representative cycle within the given strongly-connected component `scc`.

  `scc` must be a non-empty list of nodes all belonging to `graph`. Returns a list
  of nodes forming a cycle. Raises if the SCC contains no cycle (single node without
  a self-loop).
  """
  @spec find_cycle(map(), list(tuple())) :: list(tuple())
  def find_cycle(graph, scc) do
    scc_set = MapSet.new(scc)
    walk(graph, scc_set, hd(scc), %{}, [])
  end

  @doc """
  Returns one representative cycle for every strongly-connected component of `graph`
  that contains a cycle (i.e., every true attractor).

  SCCs consisting of a single node with no self-loop are skipped because they
  contain no cycle.

  Returns a list of cycles, where each cycle is a list of nodes.
  """
  @spec find_attractors(map()) :: list(list(tuple()))
  def find_attractors(graph) do
    graph
    |> scc()
    |> Enum.filter(fn
      [node] -> node in Map.get(graph, node, [])
      _ -> true
    end)
    |> Enum.map(&find_cycle(graph, &1))
  end

  @doc """
  Renders the entire product De Bruijn graph as a spacetime grid SVG.

  Every node `{a, b}` is laid out as one column (sorted for a deterministic
  order). The `k` rows represent time steps 0…k-1; cell `(t, x)` shows
  `b[t]` for the node at column `x`. Cells whose node belongs to an attractor
  cycle are filled with the per-attractor colour; other alive cells (1) are
  dark grey; dead cells (0) are white. A compact `b`-bit label is drawn below
  each column.

  ## Parameters

    * `graph`         - the product De Bruijn graph built with `build/2`
    * `initial_state` - (optional) a list of `0`/`1` values for the first row
      of the CA. When provided, exactly `length(initial_state)` columns are
      displayed: for each position `x`, the node whose `b[0]` matches
      `initial_state[x]` is selected (attractor-cycle nodes take priority).
      The initial-state row is visually separated from the rest of the grid by
      a bold border. When omitted (default `[]`), all nodes are shown.

  Returns a UTF-8 SVG binary.
  """
  @spec to_spacetime_svg(map(), list(0 | 1)) :: binary()
  def to_spacetime_svg(graph, initial_state \\ []) do
    cell = 12
    padding = 16
    label_h = 18

    k = infer_k(graph, [])
    node_colors = graph |> find_attractors() |> build_cycle_node_colors()
    all_nodes = collect_nodes(graph) |> Enum.sort()

    nodes =
      if initial_state == [] do
        all_nodes
      else
        # Partition by b[0], attractor nodes first
        {zeros, ones} =
          all_nodes
          |> Enum.sort_by(fn node -> if Map.has_key?(node_colors, node), do: 0, else: 1 end)
          |> Enum.split_with(fn {_a, b} -> elem(b, 0) == 0 end)

        # Pick one node per bit in initial_state
        {selected, _, _} =
          Enum.reduce(initial_state, {[], zeros, ones}, fn
            0, {acc, [n | zs], os} -> {[n | acc], zs, os}
            0, {acc, [], os} -> {acc, [], os}
            1, {acc, zs, [n | os]} -> {[n | acc], zs, os}
            1, {acc, zs, []} -> {acc, zs, []}
          end)

        Enum.reverse(selected)
      end

    n = length(nodes)
    total_w = n * cell + 2 * padding
    total_h = k * cell + label_h + 2 * padding

    rects =
      nodes
      |> Enum.with_index()
      |> Enum.map_join("\n", fn {{_a, b} = node, col} ->
        base_color = Map.get(node_colors, node)
        cx = padding + col * cell

        time_cells =
          Enum.map_join(0..(k - 1), "\n", fn t ->
            val = elem(b, t)

            fill =
              cond do
                val == 0 -> "white"
                base_color != nil -> base_color
                true -> "#555"
              end

            # Bold border on the initial-state row when initial_state is given
            {stroke, stroke_w} =
              if initial_state != [] and t == 0,
                do: {"#333", "1.5"},
                else: {"#ccc", "0.5"}

            cy = padding + t * cell

            ~s|<rect x="#{cx}" y="#{cy}" width="#{cell}" height="#{cell}"| <>
              ~s| fill="#{fill}" stroke="#{stroke}" stroke-width="#{stroke_w}"/>|
          end)

        b_str = b |> Tuple.to_list() |> Enum.join("")
        font_s = min(cell - 2, 9)
        ly = padding + k * cell + label_h - 4

        label =
          ~s|<text x="#{cx + div(cell, 2)}" y="#{ly}"| <>
            ~s| text-anchor="middle" font-family="monospace"| <>
            ~s| font-size="#{font_s}" fill="#666">#{b_str}</text>|

        time_cells <> "\n" <> label
      end)

    """
    <svg xmlns="http://www.w3.org/2000/svg" width="#{total_w}" height="#{total_h}">
    #{rects}
    </svg>
    """
  end

  # Rotate a cycle so the lexicographically smallest node is first,
  # giving a unique canonical form regardless of which node the DFS started from.
  defp canonicalize_cycle(cycle) do
    min_node = Enum.min(cycle)
    idx = Enum.find_index(cycle, &(&1 == min_node))
    cycle |> Stream.cycle() |> Stream.drop(idx) |> Enum.take(length(cycle))
  end

  @doc """
  Returns the adjacency matrix of `graph` together with the ordered node list.

  The result is a `{nodes, matrix}` tuple where `nodes` is the list of all nodes
  (sources and targets) and `matrix` is a list of rows of `0`/`1` integers.
  Entry `matrix[i][j] == 1` means there is an edge from `nodes[i]` to `nodes[j]`.
  """
  @spec adjacency_matrix(map()) :: {list(tuple()), list(list(integer()))}
  def adjacency_matrix(graph) do
    nodes = collect_nodes(graph)

    index =
      nodes
      |> Enum.with_index()
      |> Map.new()

    size = length(nodes)

    matrix =
      for _ <- 1..size do
        List.duplicate(0, size)
      end

    matrix =
      Enum.reduce(graph, matrix, fn {from, tos}, m ->
        i = index[from]

        Enum.reduce(tos, m, fn to, acc ->
          j = index[to]
          set_matrix(acc, i, j, 1)
        end)
      end)

    {nodes, matrix}
  end

  @doc """
  Renders `graph` as an SVG string in a circular layout.

  ## Options

    * `:radius` - radius of the node circle layout in pixels (default: `250`)
    * `:center` - x/y coordinate of the circle centre in pixels (default: `300`)
    * `:node_r` - radius of each node circle in pixels (default: `18`)
    * `:cycles` - list of attractor cycles (as returned by `find_attractors/1`);
                  nodes belonging to a cycle are filled with a distinct colour
                  per attractor (default: `[]`)

  Returns a UTF-8 encoded SVG binary suitable for writing to a file or embedding in HTML.
  """
  @spec to_svg(map(), keyword()) :: binary()
  def to_svg(graph, opts \\ []) do
    radius = Keyword.get(opts, :radius, 250)
    center = Keyword.get(opts, :center, 300)
    node_r = Keyword.get(opts, :node_r, 18)
    cycles = Keyword.get(opts, :cycles, [])

    cycle_nodes = build_cycle_node_colors(cycles)
    nodes = collect_nodes(graph)

    positions =
      nodes
      |> Enum.with_index()
      |> Enum.map(fn {node, i} ->
        angle = 2 * :math.pi() * i / length(nodes)

        x = center + radius * :math.cos(angle)
        y = center + radius * :math.sin(angle)

        {node, {x, y}}
      end)
      |> Map.new()

    """
    <svg xmlns="http://www.w3.org/2000/svg" width="600" height="600">
    <defs>
      <marker id="arrow" markerWidth="10" markerHeight="10" refX="6" refY="3" orient="auto" markerUnits="strokeWidth">
        <path d="M0,0 L0,6 L9,3 z" fill="#333"/>
      </marker>
    </defs>
    #{draw_edges(graph, positions, node_r)}
    #{draw_nodes(positions, node_r, cycle_nodes)}
    </svg>
    """
  end

  @doc """
  Computes the strongly-connected components (SCCs) of `graph` using Kosaraju's algorithm.

  Two DFS passes over the bitset adjacency representation, both O(n²):

  1. DFS on the original graph; nodes are pushed to a stack as they finish,
     yielding reverse topological order of the condensation DAG.
  2. DFS on the transposed graph in that order; each DFS tree is exactly one SCC.
  """
  @spec scc(map()) :: list(list(tuple()))
  def scc(graph) do
    nodes = graph |> collect_nodes() |> Enum.sort()
    n = length(nodes)
    index = nodes |> Enum.with_index() |> Map.new()

    bit_graph =
      Enum.map(nodes, fn node ->
        Map.get(graph, node, [])
        |> Enum.reduce(0, fn to, acc -> acc ||| 1 <<< Map.fetch!(index, to) end)
      end)

    bit_graph_t = transpose(bit_graph)

    finish_order = kosaraju_pass1(bit_graph, n)

    kosaraju_pass2(bit_graph_t, finish_order)
    |> Enum.map(fn idx_list -> Enum.map(idx_list, &Enum.at(nodes, &1)) end)
  end

  # Collect source and target nodes
  defp collect_nodes(graph) do
    sources = Map.keys(graph)

    targets =
      graph
      |> Map.values()
      |> List.flatten()

    Enum.uniq(sources ++ targets)
  end

  # Update matrix element
  defp set_matrix(matrix, i, j, value) do
    List.update_at(matrix, i, fn row ->
      List.replace_at(row, j, value)
    end)
  end

  defp draw_edges(graph, positions, node_r) do
    Enum.map_join(graph, "\n", fn {from, tos} ->
      {x1, y1} = Map.fetch!(positions, from)

      Enum.map_join(tos, "\n", fn to ->
        {x2, y2} = Map.fetch!(positions, to)

        # Shorten the line end by node_r so the arrowhead lands on the circle edge
        dx = x2 - x1
        dy = y2 - y1
        len = :math.sqrt(dx * dx + dy * dy)

        {ex, ey} =
          if len == 0.0 do
            {x2, y2}
          else
            {x2 - node_r * dx / len, y2 - node_r * dy / len}
          end

        """
        <line x1="#{x1}" y1="#{y1}"
              x2="#{ex}" y2="#{ey}"
              stroke="#888"
              stroke-width="1.5"
              marker-end="url(#arrow)"/>
        """
      end)
    end)
  end

  defp draw_nodes(positions, node_r, cycle_nodes) do
    Enum.map_join(positions, "\n", fn {node, {x, y}} ->
      label = node_label(node)
      fill = Map.get(cycle_nodes, node, "white")
      text_fill = if fill == "white", do: "#333", else: "white"

      """
      <circle cx="#{x}" cy="#{y}"
              r="#{node_r}"
              fill="#{fill}"
              stroke="#333"
              stroke-width="2"/>

      <text x="#{x}" y="#{y + 4}"
            text-anchor="middle"
            font-family="monospace"
            font-size="10"
            fill="#{text_fill}">
        #{label}
      </text>
      """
    end)
  end

  defp node_label({a, b}) do
    "#{tuple_bits(a)}|#{tuple_bits(b)}"
  end

  defp tuple_bits(t) when is_tuple(t) do
    t
    |> Tuple.to_list()
    |> Enum.join("")
  end

  defp cycle_color(i), do: Enum.at(@cycle_colors, rem(i, length(@cycle_colors)))

  defp build_cycle_node_colors(cycles) do
    cycles
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {cycle, i}, acc ->
      color = cycle_color(i)
      Enum.reduce(cycle, acc, fn node, a -> Map.put(a, node, color) end)
    end)
  end

  # Infer the temporal period k from the bit-vector size stored in nodes.
  defp infer_k(_graph, [[{_a, b} | _] | _]), do: tuple_size(b)

  defp infer_k(graph, _cycles) do
    {_a, b} = graph |> Map.keys() |> hd()
    tuple_size(b)
  end

  defp dfs(graph, start, current, path, visited) do
    Enum.flat_map(Map.get(graph, current, []), fn next ->
      cond do
        next == start ->
          [Enum.reverse(path)]

        MapSet.member?(visited, next) ->
          []

        true ->
          dfs(graph, start, next, [next | path], MapSet.put(visited, next))
      end
    end)
  end

  defp outgoing_edges({a, b}, rule_id, k) do
    for c <- all_bit_vectors(k), valid_transition?(a, b, c, rule_id, k) do
      {b, c}
    end
  end

  defp valid_transition?(a, b, c, rule_id, k) do
    Enum.all?(0..(k - 1), fn t ->
      left = elem(a, t)
      center = elem(b, t)
      right = elem(c, t)

      pattern = left <<< 2 ||| center <<< 1 ||| right
      out = rule_id >>> pattern &&& 1

      next_t = rem(t + 1, k)

      out == elem(b, next_t)
    end)
  end

  defp all_bit_vectors(k) do
    for i <- 0..((1 <<< k) - 1) do
      List.to_tuple(
        for j <- (k - 1)..0//-1 do
          i >>> j &&& 1
        end
      )
    end
  end

  # Count trailing zeros — used by Kosaraju DFS and bitset_to_list.
  # Pure integer arithmetic avoids float precision loss for indices >= 53.
  defp do_ctz(1, acc), do: acc
  defp do_ctz(n, acc), do: do_ctz(n >>> 1, acc + 1)

  # Kosaraju pass 1: iterative DFS on original graph, build finish-time order.
  # Nodes are prepended on finish, so the resulting list is in reverse finish order
  # (last-finished = source SCC of the condensation DAG = head of list).
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

  # Iterative DFS that pushes each node to the finish stack when all its
  # outgoing edges have been explored.
  defp dfs_finish(_graph, [], visited, stack), do: {visited, stack}

  defp dfs_finish(graph, [{node, remaining} | frames], visited, stack) do
    if remaining == 0 do
      # node finished
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

  # Kosaraju pass 2: iterate finish_order left-to-right (= reverse finish order),
  # running DFS on the transposed graph from each unvisited node.
  # Each DFS tree is exactly one SCC.
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

  # Iterative DFS collecting all nodes reachable from the start node into a bitset.
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

  defp transpose(graph) do
    n = length(graph)

    for j <- 0..(n - 1) do
      Enum.with_index(graph)
      |> Enum.reduce(0, fn {row, i}, acc ->
        if (row &&& 1 <<< j) != 0 do
          acc ||| 1 <<< i
        else
          acc
        end
      end)
    end
  end

  defp walk(graph, scc_set, node, visited, path) do
    if Map.has_key?(visited, node) do
      # cycle found — path was built with prepend so reverse before slicing
      cycle_start_index = visited[node]
      path |> Enum.reverse() |> Enum.drop(cycle_start_index)
    else
      visited = Map.put(visited, node, length(path))
      # O(1) prepend instead of O(n) append
      path = [node | path]

      # restrict neighbors to the SCC using MapSet for O(1) membership
      [next | _] =
        Map.get(graph, node, [])
        |> Enum.filter(&MapSet.member?(scc_set, &1))

      walk(graph, scc_set, next, visited, path)
    end
  end

  # Convert bitset → list of node indices
  defp bitset_to_list(bitset) do
    Stream.unfold(bitset, fn
      0 ->
        nil

      x ->
        lsb = x &&& -x
        idx = do_ctz(lsb, 0)
        {idx, Bitwise.bxor(x, lsb)}
    end)
    |> Enum.to_list()
  end
end
