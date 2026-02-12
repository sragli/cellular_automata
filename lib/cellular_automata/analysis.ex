defmodule CellularAutomata.Analysis do
  @doc """
  Hamming distance between two states (lists of equal length).
  Works with any CA states (ECA, Four-Colour, or other).

  ## Parameters
  - `s1`: CA state (list of values)
  - `s2`: CA state (list of values)
  """
  @spec hamming_distance(list(), list()) :: non_neg_integer()
  def hamming_distance(s1, s2) when length(s1) == length(s2) do
    Enum.zip(s1, s2)
    |> Enum.reduce(0, fn {x, y}, acc -> acc + if x == y, do: 0, else: 1 end)
  end

  @doc """
  Computes finite-time exponents λ(t) = (1 / t) ln d(t).
  Works with any CA evolution (ECA, Four-Colour, or other).

  ## Parameters
  Both lists must have the same length and correspond to time evolution of two initial conditions.
  - `ca1`: CA evolution (list of states correspond to time evolution of the initial conditions)
  - `ca2`: CA evolution (list of states correspond to time evolution of the initial conditions)

  Returns list of {t, λ(t)}.
  """
  @spec lyapunov_exponent(list(), list()) :: list({pos_integer(), float()})
  def lyapunov_exponent(ca1, ca2) when length(ca1) == length(ca2) do
    Enum.zip(ca1, ca2)
    |> Enum.with_index(1)
    |> Enum.map(fn {{s1, s2}, t} ->
      d = hamming_distance(s1, s2)

      {t, :math.log(d) / t}
    end)
  end

  @doc """
  Computes BDM (Block Decomposition Method) complexity of an ECA.

  ## Parameters
  - `ca`: ECA (list of states correspond to time evolution of the initial conditions)
  """
  @spec bdm_complexity(CellularAutomata.binary_matrix()) :: float()
  def bdm_complexity(ca) do
    bdm = BDM.new(2, 2, 3, :ignore)
    BDM.compute(bdm, ca)
  end
end
