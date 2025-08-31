defmodule CellularAutomata.RuleGenerator do
  @doc """
  Generates all 256 elementary cellular automaton rules.
  Returns a map where each key is a rule number (0-255) and each value is a map
  representing the rule's transition function.
  """

  @spec generate_all_rules() :: list(map())
  def generate_all_rules() do
    0..255
    |> Enum.map(fn rule_id -> {rule_id, generate_rule(rule_id)} end)
    |> Enum.into(%{})
  end

  @doc """
  Generates a single elementary cellular automaton rule given its rule number.

  The rule number is an 8-bit binary representation where each bit corresponds
  to the output for one of the 8 possible neighborhood configurations:
  - Bit 7: {1,1,1} -> bit_7
  - Bit 6: {1,1,0} -> bit_6
  - Bit 5: {1,0,1} -> bit_5
  - Bit 4: {1,0,0} -> bit_4
  - Bit 3: {0,1,1} -> bit_3
  - Bit 2: {0,1,0} -> bit_2
  - Bit 1: {0,0,1} -> bit_1
  - Bit 0: {0,0,0} -> bit_0
  """
  @spec generate_rule(non_neg_integer()) :: map()
  def generate_rule(rule_number) when rule_number >= 0 and rule_number <= 255 do
    # All possible neighborhood configurations in order
    neighborhoods = [
      # 7
      {1, 1, 1},
      # 6
      {1, 1, 0},
      # 5
      {1, 0, 1},
      # 4
      {1, 0, 0},
      # 3
      {0, 1, 1},
      # 2
      {0, 1, 0},
      # 1
      {0, 0, 1},
      # 0
      {0, 0, 0}
    ]

    bits = extract_bits(rule_number)

    neighborhoods
    |> Enum.zip(bits)
    |> Enum.into(%{})
  end

  # Extracts the 8 bits from a rule number (0-255) as a list.
  # Returns bits in order from most significant (bit 7) to least significant (bit 0).
  defp extract_bits(rule_number) do
    7..0//-1
    |> Enum.map(fn bit_position ->
      rule_number |> Bitwise.bsr(bit_position) |> Bitwise.band(1)
    end)
  end
end
