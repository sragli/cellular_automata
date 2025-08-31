# CellularAutomata

Elixir module to create cellular automata.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `cellular_automata` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cellular_automata, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
initial_state = [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0]

evolution = CellularAutomata.rule_30(initial_state, 20)
```