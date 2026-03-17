# CellularAutomata

Elixir module to create and analyse cellular automata.

## Features

* `CellularAutomata.elementary/3`: Creates a 1D (Elementary) Cellular Automaton
* `CellularAutomata.four_colour/3`: Creates a 1D Four Colour Cellular Automaton
* `CellularAutomata.Analysis.hamming_distance/2`: Calculates Hamming-distance between two CA states
* `CellularAutomata.Analysis.lyapunov_exponent/2`: Calculates the Lyapunov exponent between states of two CAs
* `CellularAutomata.Analysis.bdm_complexity/1`: Calculates the BDM complexity of an ECA
* `CellularAutomata.DeBruijnGraph`: Creates De Bruijn graphs from cellular automata rules
* `CellularAutomata.ProductDeBruijnGraph`: Creates product De Bruijn graphs from cellular automata rules

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `cellular_automata` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cellular_automata, "~> 0.3.0"}
  ]
end
```

## Usage

```elixir
initial_state = [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0]

# Evolve the initial state in 20 steps using rule 30
evolution = CellularAutomata.elementary(initial_state, 20, 30)
```
