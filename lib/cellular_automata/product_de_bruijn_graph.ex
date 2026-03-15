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
    Enum.flat_map(Map.keys(graph), fn node ->
      dfs(graph, node, node, [node])
    end)
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

  @doc """
  Counts all length - n spatially periodic configurations.
  """
  def count_periodic_patterns(graph, n) do
    {_nodes, matrix} = adjacency_matrix(graph)

    matrix
    |> pow(n)
    |> trace()
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

  defp dfs(graph, start, current, path) do
    Enum.flat_map(Map.get(graph, current, []), fn next ->
      cond do
        next == start ->
          [Enum.reverse([next | path])]

        next in path ->
          []

        true ->
          dfs(graph, start, next, [next | path])
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
        for j <- (k - 1)..0 do
          i >>> j &&& 1
        end
      )
    end
  end

  defp multiply(a, b) do
    cols = transpose(b)

    for row <- a do
      for col <- cols do
        if Enum.any?(Enum.zip(row, col), fn {r, c} -> r == 1 and c == 1 end), do: 1, else: 0
      end
    end
  end

  defp transpose(matrix) do
    matrix
    |> List.zip()
    |> Enum.map(&Tuple.to_list/1)
  end

  defp pow(m, 1), do: m

  defp pow(m, n) when rem(n, 2) == 0 do
    half = pow(m, div(n, 2))
    multiply(half, half)
  end

  defp pow(m, n) do
    half = pow(m, div(n, 2))
    multiply(multiply(half, half), m)
  end

  defp trace(matrix) do
    matrix
    |> Enum.with_index()
    |> Enum.reduce(0, fn {row, i}, acc -> acc + Enum.at(row, i) end)
  end
end
