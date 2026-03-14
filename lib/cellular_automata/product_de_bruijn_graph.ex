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

  @spec to_svg(map()) :: binary()
  def to_svg(graph, opts \\ []) do
    radius = Keyword.get(opts, :radius, 250)
    center = Keyword.get(opts, :center, 300)
    node_r = Keyword.get(opts, :center, 18)

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
      <marker id="arrow" markerWidth="10" markerHeight="10"
              refX="6" refY="3"
              orient="auto"
              markerUnits="strokeWidth">
        <path d="M0,0 L0,6 L9,3 z" fill="#333"/>
      </marker>
    </defs>
    #{draw_edges(graph, positions)}
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

  defp draw_edges(graph, positions) do
    Enum.map_join(graph, "\n", fn {from, tos} ->
      {x1, y1} = Map.fetch!(positions, from)

      Enum.map_join(tos, "\n", fn to ->
        {x2, y2} = Map.fetch!(positions, to)

        """
        <line x1="#{x1}" y1="#{y1}"
              x2="#{x2}" y2="#{y2}"
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
end
