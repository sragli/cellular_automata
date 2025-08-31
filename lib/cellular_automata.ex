defmodule CellularAutomata do
  @moduledoc """
  Module for creating 1D cellular automata.
  """

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

  def rule_30(initial_state, steps) do
    evolve(initial_state, steps, @rule30)
  end

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
