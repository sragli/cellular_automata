defmodule CellularAutomata.AttractorNetwork do
  @moduledoc """
  Given a product De Bruijn graph (built with `CellularAutomata.ProductDeBruijnGraph.build/2`),
  this module:

  1. Identifies every attractor (limit cycle) of the CA.
  2. Extracts a canonical representative state for each attractor.
  3. Applies a configurable perturbation scheme to each representative.
  4. Evolves each perturbed state forward until it reaches an attractor,
     recording which attractor it converges to.
  5. Returns the resulting directed graph as an adjacency map.

  The output can be used to study robustness (how easily the system escapes an
  attractor), the basin structure, and global flow properties of the rule.
  """

  import Bitwise
  alias CellularAutomata.ProductDeBruijnGraph

  @doc """
  Builds the attractor network for the given product De Bruijn `graph` and ECA
  `rule_id`.

  ## Parameters

    * `graph`   - a product De Bruijn graph as returned by
      `CellularAutomata.ProductDeBruijnGraph.build/2`.
    * `rule_id` - integer Wolfram code of the elementary cellular automaton
      rule (0–255).
    * `opts`    - keyword options:
      * `:perturbations` - perturbation scheme applied to each attractor
        representative before re-evolving. Supported values:
        * `:single_bit` *(default)* — flip each cell independently, producing
          `n` single-bit-flip variants of a length-`n` state.
        * `:none` — do not perturb; every attractor maps to itself.

  ## Return value

  A map with three keys:

    * `:attractors`      — list of attractor cycles as returned by
      `ProductDeBruijnGraph.find_attractors/1`; each cycle is a list of
      `{a, b}` product-De-Bruijn-graph nodes.
    * `:representatives` — list of canonical t=0 states, one per attractor.
      Each state is a list of `0`/`1` integers whose length equals the number
      of nodes in the attractor cycle.
    * `:edges`           — map from attractor index to the list of attractor
      indices reachable under the chosen perturbation scheme (self-loops
      included).

  ## Example

      graph = CellularAutomata.ProductDeBruijnGraph.build(110, 2)
      CellularAutomata.AttractorNetwork.build(graph, 110)
      # => %{attractors: [...], representatives: [...], edges: %{0 => [0], 1 => [1]}}

  """
  @spec build(map(), non_neg_integer(), keyword()) :: %{
          attractors: list(list(tuple())),
          representatives: list(list(0 | 1)),
          edges: %{non_neg_integer() => list(non_neg_integer())}
        }
  def build(graph, rule_id, opts \\ []) do
    perturbations = Keyword.get(opts, :perturbations, :single_bit)

    attractors = ProductDeBruijnGraph.find_attractors(graph)

    # Infer temporal period k from the graph nodes
    k = graph |> Map.keys() |> hd() |> elem(1) |> tuple_size()

    # canonical representatives (t=0 slice of each attractor cycle)
    reps =
      Enum.map(attractors, fn cycle ->
        cycle_to_state(cycle, 0)
      end)

    # map ALL temporal-phase states of every attractor -> attractor index
    index_map =
      attractors
      |> Enum.with_index()
      |> Enum.flat_map(fn {cycle, i} ->
        for t <- 0..(k - 1) do
          {cycle_to_state(cycle, t), i}
        end
      end)
      |> Map.new()

    rf = rule_fun(rule_id)

    edges =
      Enum.with_index(reps)
      |> Enum.reduce(%{}, fn {state, i}, acc ->
        targets =
          perturb(state, perturbations)
          |> Enum.map(fn perturbed ->
            final = evolve_to_attractor(perturbed, rf)
            Map.get(index_map, final)
          end)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()

        Map.put(acc, i, targets)
      end)

    %{
      attractors: attractors,
      representatives: reps,
      edges: edges
    }
  end

  # --- REPRESENTATION ---

  # extract the state at time-slice t from a PDBG cycle.
  # Each node {_a, b} contributes one cell; elem(b, t) is that cell's value at time t.
  defp cycle_to_state(cycle, t) do
    Enum.map(cycle, fn {_a, b} -> elem(b, t) end)
  end

  # --- PERTURBATIONS ---

  defp perturb(state, :single_bit) do
    n = length(state)

    for i <- 0..(n - 1) do
      List.update_at(state, i, fn b -> 1 - b end)
    end
  end

  defp perturb(state, :none), do: [state]

  # --- EVOLUTION ---

  defp evolve_to_attractor(state, rule_fun) do
    iterate(state, rule_fun, %{})
  end

  defp iterate(state, rule_fun, seen) do
    if Map.has_key?(seen, state) do
      state
    else
      next = step(state, rule_fun)
      iterate(next, rule_fun, Map.put(seen, state, true))
    end
  end

  defp step(state, rule_fun) do
    n = length(state)

    for x <- 0..(n - 1) do
      left = Enum.at(state, rem(x - 1 + n, n))
      mid = Enum.at(state, x)
      right = Enum.at(state, rem(x + 1, n))

      rule_fun.({left, mid, right})
    end
  end

  # Returns a function implementing the rule.
  defp rule_fun(rule) when is_integer(rule) and rule >= 0 and rule <= 255 do
    fn {l, c, r} ->
      idx = l <<< 2 ||| c <<< 1 ||| r
      rule >>> idx &&& 1
    end
  end
end
