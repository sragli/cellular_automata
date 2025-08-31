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
end
