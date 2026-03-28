defmodule CellularAutomata.TopologicalEntropy do
  @moduledoc """
  Compute topological entropy from a product De Bruijn graph of an ECA rule.

  Entropy measures how quickly the number of valid configurations grows

  * low entropy → simple dynamics
  * high entropy → chaotic dynamics

  For a finite directed graph, the topological entropy is: $h = log ⁡λ_{max}⁡$, where $λ_{max}$
  is the spectral radius (largest eigenvalue) of the adjacency matrix.
  """
  alias CellularAutomata.ProductDeBruijnGraph

  @spec entropy(ProductDeBruijnGraph.t()) :: float()
  def entropy(graph) do
    {_nodes, matrix} = ProductDeBruijnGraph.adjacency_matrix(graph)

    matrix
    |> spectral_radius()
    |> :math.log()
  end

  defp spectral_radius(matrix, tol \\ 1.0e-10, max_iter \\ 1_000) do
    n = length(matrix)

    v =
      for _ <- 1..n do
        1.0 / n
      end

    power_iteration(matrix, v, 0.0, tol, max_iter, 0)
  end

  defp power_iteration(_m, _v, lambda, _tol, max_iter, iter) when iter >= max_iter do
    lambda
  end

  defp power_iteration(m, v, _lambda, tol, max_iter, iter) do
    v_next = mat_vec_mul(m, v)
    lambda = norm(v_next)
    v_next = Enum.map(v_next, &(&1 / lambda))

    if distance(v, v_next) < tol do
      lambda
    else
      power_iteration(m, v_next, lambda, tol, max_iter, iter + 1)
    end
  end

  defp mat_vec_mul(m, v) do
    Enum.map(m, fn row ->
      Enum.zip(row, v)
      |> Enum.map(fn {a, b} -> a * b end)
      |> Enum.sum()
    end)
  end

  defp norm(v) do
    :math.sqrt(Enum.reduce(v, 0.0, fn x, acc -> acc + x * x end))
  end

  defp distance(v1, v2) do
    Enum.zip(v1, v2)
    |> Enum.map(fn {a, b} -> (a - b) * (a - b) end)
    |> Enum.sum()
    |> :math.sqrt()
  end
end
