defmodule CellularAutomata do
  @moduledoc """
  Module for creating elementary cellular automata.
  """

  @type binary_list :: list(0 | 1)
  @type binary_matrix :: list(binary_list())

  @doc """
  Shortcut to CA evolution using the specified CA rule.

  ## Parameters
  - `initial_state`: 2D matrix (list of lists) representing the initial state
  - `steps`: Number of steps in the evolution
  - `rule_id`: Number of the CA rule
  """
  @spec create(binary_list(), non_neg_integer(), non_neg_integer()) :: binary_matrix()
  def create(initial_state, steps, rule_id) do
    rule = CellularAutomata.RuleGenerator.generate_rule(rule_id)
    evolve(initial_state, steps, rule)
  end

  @doc """
  Evolves the initial state using the supplied rule.

  ## Parameters
  - `state`: 2D matrix (list of lists) representing the initial state
  - `steps`: Number of steps in the evolution
  - `rule`: Update rule (map of patterns (`{0 | 1, 0 | 1, 0 | 1}`) and next value (`0 | 1`))
  """
  @spec evolve(binary_list(), non_neg_integer(), map()) :: binary_matrix()
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
