defmodule CellularAutomata.FourColour do
  @moduledoc """
  Module for creating four-colour cellular automata.
  """

  @doc """
  Shortcut to CA evolution using the specified CA rule.

  ## Parameters
  - `initial_state`: 2D matrix (list of lists) representing the initial state
  - `steps`: Number of steps in the evolution
  - `rule`: Update rule (map of patterns and next values)

  ## Example
      iex> rule = %{
      ...>   {0, 0, 0} => 1,
      ...>   {0, 0, 1} => 0,
      ...>   {0, 1, 0} => 2,
      ...>   {0, 1, 1} => 3,
      ...>   {1, 0, 0} => 1,
      ...>   {1, 0, 1} => 2,
      ...>   {1, 1, 0} => 3,
      ...>   {1, 1, 1} => 0
      ...> }
      iex> CellularAutomata.FourColour.create([0, 1, 0], 2, rule)
      [[0, 1, 0], [2, 0, 3], [3, 1, 0]]
  """
  @spec create(list(), non_neg_integer(), map()) :: list()
  def create(initial_state, steps, rule) do
    evolve(initial_state, steps, rule)
  end

  @doc """
  Evolves the initial state using the supplied rule.

  ## Parameters
  - `state`: 2D matrix (list of lists) representing the initial state
  - `steps`: Number of steps in the evolution
  - `rule`: Update rule (map of patterns and next values)
  """
  @spec evolve(list(), non_neg_integer(), map()) :: list()
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
