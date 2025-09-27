# CellularAutomata

Elixir module to create and analyse cellular automata.

## Features

* `CellularAutomata.elementary/3`: Creates a 1D (Elementary) Cellular Automaton
* `CellularAutomata.Analysis.hamming_distance/2`: Calculates Hamming-distance between two ECA states
* `CellularAutomata.Analysis.lyapunov_exponent/2`: Calculates the Lyapunov exponent between states of two ECAs
* `CellularAutomata.Analysis.bdm_complexity/1`: Calculates the BDM complexity of an ECA

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
evolution = CellularAutomata.elementary(initial_state, 20, 30)
```
