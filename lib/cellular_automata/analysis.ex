defmodule CellularAutomata.Analysis do
  @doc """
  Hamming distance between two states (lists of equal length).

  ## Parameters
  - `s1`: CA state (list of binary numbers)
  - `s2`: CA state (list of binary numbers)
  """
  @spec hamming_distance(CellularAutomata.binary_list(), CellularAutomata.binary_list()) ::
          non_neg_integer()
  def hamming_distance(s1, s2) when length(s1) == length(s2) do
    Enum.zip(s1, s2)
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
  @spec lyapunov_exponent(CellularAutomata.binary_list(), CellularAutomata.binary_list()) ::
          list({pos_integer(), number()})
  def lyapunov_exponent(ca1, ca2) when length(ca1) == length(ca2) do
    Enum.zip(ca1, ca2)
    |> Enum.with_index(1)
    |> Enum.map(fn {{s1, s2}, t} ->
      d = hamming_distance(s1, s2)

      {t, :math.log(d) / t}
    end)
  end
end
