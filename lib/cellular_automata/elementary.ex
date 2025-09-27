defmodule CellularAutomata.Elementary do
  @moduledoc """
  Module for creating elementary cellular automata.
  """

  @doc """
  Shortcut to CA evolution using the specified CA rule.

  ## Parameters
  - `initial_state`: 2D matrix (list of lists) representing the initial state
  - `steps`: Number of steps in the evolution
  - `rule_id`: Number of the CA rule
  """
  @spec create(CellularAutomata.binary_list(), non_neg_integer(), non_neg_integer()) ::
          CellularAutomata.binary_matrix()
  def create(initial_state, steps, rule_id) do
    rule = CellularAutomata.ECARuleGenerator.generate_rule(rule_id)
    evolve(initial_state, steps, rule)
  end

  @doc """
  Evolves the initial state using the supplied rule.

  ## Parameters
  - `state`: 2D matrix (list of lists) representing the initial state
  - `steps`: Number of steps in the evolution
  - `rule`: Update rule (map of patterns (`{0 | 1, 0 | 1, 0 | 1}`) and next value (`0 | 1`))
  """
  @spec evolve(CellularAutomata.binary_list(), non_neg_integer(), map()) ::
          CellularAutomata.binary_matrix()
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
