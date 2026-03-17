defmodule CellularAutomata.ProductDeBruijnGraph do
  @moduledoc """
  Spatio-temporal cycle detection using the product De Bruijn graph.
  This allows detecting period-k attractors directly, without enumerating $$2^N$$
  global states.
  """
  import Bitwise

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

  @spec find_cycles(map()) :: list(list(tuple()))
  def find_cycles(graph) do
    graph
    |> Map.keys()
    |> Enum.flat_map(fn node -> dfs(graph, node, node, [node], MapSet.new([node])) end)
    |> Enum.map(&canonicalize_cycle/1)
    |> Enum.uniq()
  end

  # Rotate a cycle so the lexicographically smallest node is first,
  # giving a unique canonical form regardless of which node the DFS started from.
  defp canonicalize_cycle(cycle) do
    min_node = Enum.min(cycle)
    idx = Enum.find_index(cycle, &(&1 == min_node))
    cycle |> Stream.cycle() |> Stream.drop(idx) |> Enum.take(length(cycle))
  end

  @spec adjacency_matrix(map()) :: map()
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

    all = (1 <<< n) - 1

    do_scc(bit_graph, all, [])
    |> Enum.map(fn idx_list -> Enum.map(idx_list, &Enum.at(nodes, &1)) end)
  end

  @spec to_svg(map()) :: binary()
  def to_svg(graph, opts \\ []) do
    radius = Keyword.get(opts, :radius, 250)
    center = Keyword.get(opts, :center, 300)
    node_r = Keyword.get(opts, :node_r, 18)

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
    #{draw_nodes(positions, node_r)}
    </svg>
    """
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

  defp draw_nodes(positions, node_r) do
    Enum.map_join(positions, "\n", fn {node, {x, y}} ->
      label = node_label(node)

      """
      <circle cx="#{x}" cy="#{y}"
              r="#{node_r}"
              fill="white"
              stroke="#333"
              stroke-width="2"/>

      <text x="#{x}" y="#{y + 4}"
            text-anchor="middle"
            font-family="monospace"
            font-size="10">
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

  # Recursive decomposition
  defp do_scc(_graph, 0, acc), do: acc

  defp do_scc(graph, remaining, acc) do
    v = pick_node(remaining)

    fwd = reachable_forward(graph, v)
    bwd = reachable_backward(graph, v)

    scc = fwd &&& bwd

    remaining = remaining &&& bnot(scc)

    do_scc(graph, remaining, [bitset_to_list(scc) | acc])
  end

  # Pick lowest set bit (count trailing zeros with pure integer arithmetic,
  # avoiding float precision loss for indices >= 53)
  defp pick_node(bitset) do
    lsb = bitset &&& -bitset
    do_ctz(lsb, 0)
  end

  defp do_ctz(1, acc), do: acc
  defp do_ctz(n, acc), do: do_ctz(n >>> 1, acc + 1)

  # Forward reachability (BFS with bitsets)
  defp reachable_forward(graph, start) do
    bfs(graph, 1 <<< start)
  end

  # Backward reachability using transposed graph
  defp reachable_backward(graph, start) do
    graph
    |> transpose()
    |> bfs(1 <<< start)
  end

  # Bitset BFS
  defp bfs(graph, frontier) do
    bfs(graph, frontier, frontier)
  end

  defp bfs(graph, frontier, visited) do
    next =
      Enum.with_index(graph)
      |> Enum.reduce(0, fn {row, i}, acc ->
        if (frontier &&& 1 <<< i) != 0 do
          acc ||| row
        else
          acc
        end
      end)

    new = next &&& bnot(visited)

    if new == 0 do
      visited
    else
      bfs(graph, new, visited ||| new)
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
