defmodule CellularAutomata.Analysis do
  @doc "Hamming distance between two states (lists of equal length)."
  def hamming_distance(a, b) when length(a) == length(b) do
    Enum.zip(a, b)
    |> Enum.reduce(0, fn {x, y}, acc -> acc + if x == y, do: 0, else: 1 end)
  end

  @doc """
  Computes finite-time exponents λ(t) = (1 / t) ln d(t).

  ## Parameters
  Both lists must have the same length and correspond to time evolution of two initial conditions.
  - `ca1`: first ECA (list of states correspond to time evolution of the initial conditions)
  - `ca2`: second ECA (list of states correspond to time evolution of the initial conditions)

  Returns list of {t, λ(t)}.
  """
  def lyapunov_exponent(ca1, ca2) when length(ca1) == length(ca2) do
    Enum.zip(ca1, ca2)
    |> Enum.with_index(1)
    |> Enum.map(fn {{sa, sb}, t} ->
      d = hamming_distance(sa, sb)

      {t, :math.log(d) / t}
    end)
  end
end
