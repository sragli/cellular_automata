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
  Each state of an Elementary Cellular Automaton can be described by a integer number,
  in which, the number of bits and their positions correspond to the bits in that
  particular CA state.
  Thus, any ECA can be represented by a list of non-negative integer numbers. This is a
  more compact representation, better suited for comparing large numbers of states of
  different ECAs.
  """
  @spec compact(binary_matrix()) :: list(non_neg_integer())
  def compact(ca) do
    ca
    |> Enum.map(fn state  ->
        state
        |> Enum.join()
        |> String.to_integer(2)
      end)
  end
end
