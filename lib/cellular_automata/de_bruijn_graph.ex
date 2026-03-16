defmodule CellularAutomata.DeBruijnGraph do
  @moduledoc """
  The De Bruijn graph encodes all allowed spatial overlaps of neighborhoods (e.g. the local rule constraints).

  Each edge represents a neighborhood: abc : ab → bc
  A path corresponds to a spatial configuration. A cycle of length k corresponds to a spatially periodic
  configuration with period k.
  Thus we can derive periodic patterns, fixed structures, repeating attractors.
  Since global behavior emerges from local interactions, the topology of this graph encodes the rule's dynamics.
  """
  import Bitwise

  @spec build(non_neg_integer) :: map()
  def build(rule_id) do
    Enum.reduce(0..7, %{}, fn pattern, g ->
      a = pattern >>> 2 &&& 1
      b = pattern >>> 1 &&& 1
      c = pattern &&& 1

      from = {a, b}
      to = {b, c}
      out = rule_id >>> pattern &&& 1

      Map.update(g, from, [{to, out}], &[{to, out} | &1])
    end)
  end

  @spec adjacency_matrix(map()) :: map()
  def adjacency_matrix(graph) do
    nodes = graph |> Map.keys() |> Enum.sort()
    n = length(nodes)
    index = nodes |> Enum.with_index() |> Map.new()

    matrix = for _ <- 1..n, do: List.duplicate(0, n)

    Enum.reduce(graph, matrix, fn {from, neighbors}, mat ->
      Enum.reduce(neighbors, mat, fn {to, _label}, mat ->
        i = Map.fetch!(index, from)
        j = Map.fetch!(index, to)

        List.update_at(mat, i, fn row ->
          List.update_at(row, j, fn _ -> 1 end)
        end)
      end)
    end)
  end

  @spec print_adjacency_matrix(map()) :: :ok
  def print_adjacency_matrix(graph) do
    nodes = graph |> Map.keys() |> Enum.sort()
    matrix = adjacency_matrix(graph)

    col_headers = nodes |> Enum.map(&inspect/1) |> Enum.join("  ")
    IO.puts("         #{col_headers}")

    Enum.zip(nodes, matrix)
    |> Enum.each(fn {node, row} ->
      row_str = row |> Enum.map(&to_string/1) |> Enum.join("        ")
      IO.puts("#{inspect(node)}  #{row_str}")
    end)
  end

  @spec find_cycles(map()) :: list(list({0 | 1, 0 | 1}))
  def find_cycles(graph) do
    nodes = Map.keys(graph)

    Enum.flat_map(nodes, fn node ->
      dfs(graph, node, node, [node])
    end)
  end

  @doc """
  Counts all length - n spatially periodic configurations.
  """
  def count_periodic_patterns(graph, n) do
    graph
    |> adjacency_matrix()
    |> pow(n)
    |> trace()
  end

  defp dfs(graph, start, current, path) do
    Enum.flat_map(Map.get(graph, current, []), fn {next, _} ->
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
    |> Enum.zip()
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
