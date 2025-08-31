# CellularAutomata

Elixir module to create elementary cellular automata.

In the elementary CA, each rule maps the 8 possible neighborhood configurations (3 cells: left, center, right) to an output value. Since the states are binary, it means that altogether there are 256 rules.

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

# Evolve the initial state in 20 steps using rule 30
evolution = CellularAutomata.create(initial_state, 20, 30)
```