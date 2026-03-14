defmodule CellularAutomata.DeBruijnGraph do
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
end
