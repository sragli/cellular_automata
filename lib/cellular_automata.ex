defmodule CellularAutomata do
  @moduledoc """
  Module for creating 1D cellular automata.
  """

  @type binary_matrix :: list(list(integer()))

  @rule30 %{
    {1, 1, 1} => 0,
    {1, 1, 0} => 0,
    {1, 0, 1} => 0,
    {1, 0, 0} => 1,
    {0, 1, 1} => 1,
    {0, 1, 0} => 1,
    {0, 0, 1} => 1,
    {0, 0, 0} => 0
  }

  @doc """
  Shortcut to CA evolution using rule 30.

  ## Parameters
  - `initial_state`: 2D matrix (list of lists) representing the initial state
  - `steps`: Number of steps in the evolution
  """
  @spec rule_30(binary_matrix(), non_neg_integer()) :: binary_matrix()
  def rule_30(initial_state, steps) do
    evolve(initial_state, steps, @rule30)
  end

  @doc """
  Evolves the initial state using the supplied rule.

  ## Parameters
  - `state`: 2D matrix (list of lists) representing the initial state
  - `steps`: Number of steps in the evolution
  - `rule`: Update rule (map of patterns (`{0 | 1, 0 | 1, 0 | 1}`) and next value (`0 | 1`))
  """
  @spec evolve(binary_matrix(), non_neg_integer(), map()) :: binary_matrix()
  def evolve(state, 0, _rule), do: [state]

  def evolve(state, steps, rule) do
    next_state = next(state, rule)
    [state | evolve(next_state, steps - 1, rule)]
  end

  defp next(state, rule) do
    len = length(state)

    for i <- 0..(len - 1) do
      left = Enum.at(state, rem(i - 1 + len, len))
      center = Enum.at(state, i)
      right = Enum.at(state, rem(i + 1, len))

      rule[{left, center, right}]
    end
  end
end
