defmodule CellularAutomata do
  @moduledoc false

  @type binary_list :: list(0 | 1)
  @type binary_matrix :: list(binary_list())

  @doc """
  Creates an Elementary CA based on the specified initial conditions and evolves it using
  the supplied rule.

  ## Parameters
  - `initial_state`: 2D matrix (list of lists) representing the initial state
  - `steps`: Number of steps in the evolution
  - `rule_id`: Number of the CA rule
  """
  @spec elementary(binary_list(), non_neg_integer(), non_neg_integer()) :: binary_matrix()
  def elementary(initial_state, steps, rule_id) do
    CellularAutomata.Elementary.create(initial_state, steps, rule_id)
  end

  @doc """
  Creates a Four-Colour, 1D CA based on the specified initial conditions and evolves it
  using the supplied rule.

  ## Parameters
  - `initial_state`: 2D matrix (list of lists) representing the initial state
  - `steps`: Number of steps in the evolution
  - `rule`: Update rule (map of patterns and next values)
  """
  @spec four_colour(list(), non_neg_integer(), map()) :: list()
  def four_colour(initial_state, steps, rule) do
    CellularAutomata.FourColour.create(initial_state, steps, rule)
  end

  @doc """
  Each state of an Elementary Cellular Automaton can be described by a integer number,
  in which, the number of bits and their positions correspond to the bits in that
  particular CA state.
  Thus, any ECA can be represented by a list of non-negative integer numbers. This is a
  more compact representation, better suited for comparing large numbers of states of
  different ECAs.

  The limitation is that the representation will loose information about the number of
  bits in the original state, so it should be used only for comparing states of the
  same length.
  """
  @spec compact(binary_matrix()) :: list(non_neg_integer())
  def compact(ca) do
    ca
    |> Enum.map(fn state ->
      state
      |> Enum.join()
      |> String.to_integer(2)
    end)
  end

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
  Works only with ECAs (binary lists).

  ## Parameters
  - `ca`: ECA (list of states correspond to time evolution of the initial conditions)
  """
  @spec bdm_complexity(CellularAutomata.binary_matrix()) :: float()
  def bdm_complexity(ca) do
    bdm = BDM.new(2, 2, 3, :ignore)
    BDM.compute(bdm, ca)
  end
end
