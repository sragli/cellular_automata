defmodule CellularAutomata.ProductDeBruijnGraphTest do
  use ExUnit.Case, async: true

  alias CellularAutomata.ProductDeBruijnGraph

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Normalise edge lists to sets so order doesn't matter in assertions.
  defp edge_set(graph) do
    Enum.flat_map(graph, fn {from, tos} -> Enum.map(tos, fn to -> {from, to} end) end)
    |> MapSet.new()
  end

  # ---------------------------------------------------------------------------
  # build/2
  # ---------------------------------------------------------------------------

  describe "build/2 – rule 0, k=1" do
    # Rule 0 always outputs 0, so only nodes with b={0} can have outgoing edges
    # (the rule must produce b[(t+1) mod k] = b[0] for all t, and b[0] must be 0).
    setup do
      {:ok, graph: ProductDeBruijnGraph.build(0, 1)}
    end

    test "has exactly 2 source nodes", %{graph: g} do
      assert map_size(g) == 2
    end

    test "{{0},{0}} and {{1},{0}} are the only source nodes", %{graph: g} do
      assert Map.has_key?(g, {{0}, {0}})
      assert Map.has_key?(g, {{1}, {0}})
    end

    test "both source nodes have exactly 2 outgoing edges", %{graph: g} do
      assert length(g[{{0}, {0}}]) == 2
      assert length(g[{{1}, {0}}]) == 2
    end

    test "both source nodes lead to {{0},{0}} and {{0},{1}}", %{graph: g} do
      edges = edge_set(g)

      assert {{{0}, {0}}, {{0}, {0}}} in edges
      assert {{{0}, {0}}, {{0}, {1}}} in edges
      assert {{{1}, {0}}, {{0}, {0}}} in edges
      assert {{{1}, {0}}, {{0}, {1}}} in edges
    end

    test "nodes with b={1} have no outgoing edges", %{graph: g} do
      refute Map.has_key?(g, {{0}, {1}})
      refute Map.has_key?(g, {{1}, {1}})
    end
  end

  describe "build/2 – rule 255, k=1" do
    # Rule 255 always outputs 1, so only nodes with b={1} can have outgoing edges.
    setup do
      {:ok, graph: ProductDeBruijnGraph.build(255, 1)}
    end

    test "has exactly 2 source nodes", %{graph: g} do
      assert map_size(g) == 2
    end

    test "{{0},{1}} and {{1},{1}} are the only source nodes", %{graph: g} do
      assert Map.has_key?(g, {{0}, {1}})
      assert Map.has_key?(g, {{1}, {1}})
    end

    test "both source nodes lead to {{1},{0}} and {{1},{1}}", %{graph: g} do
      edges = edge_set(g)

      assert {{{0}, {1}}, {{1}, {0}}} in edges
      assert {{{0}, {1}}, {{1}, {1}}} in edges
      assert {{{1}, {1}}, {{1}, {0}}} in edges
      assert {{{1}, {1}}, {{1}, {1}}} in edges
    end

    test "nodes with b={0} have no outgoing edges", %{graph: g} do
      refute Map.has_key?(g, {{0}, {0}})
      refute Map.has_key?(g, {{1}, {0}})
    end
  end

  describe "build/2 – k=2 structural properties" do
    test "nodes are pairs of 2-bit vectors" do
      graph = ProductDeBruijnGraph.build(110, 2)
      # Each node is {{b0,b1},{b0,b1}} – tuples of length 2
      Enum.each(graph, fn {{a, b}, _} ->
        assert tuple_size(a) == 2
        assert tuple_size(b) == 2
      end)
    end

    test "edges preserve the De Bruijn shift: {a,b}→{b,c}" do
      graph = ProductDeBruijnGraph.build(110, 2)

      Enum.each(graph, fn {{_a, b}, tos} ->
        Enum.each(tos, fn {b2, _c} ->
          assert b == b2,
                 "Edge does not satisfy shift structure: target first component should equal source second component"
        end)
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # find_cycles/1
  # ---------------------------------------------------------------------------

  describe "find_cycles/1" do
    test "rule 0, k=1: only the all-zeros fixed point" do
      cycles =
        ProductDeBruijnGraph.build(0, 1)
        |> ProductDeBruijnGraph.find_cycles()

      # The only attractor: uniform-0 state stays uniform-0 forever.
      # Cycle is canonicalised and closed without repeating the start node.
      assert cycles == [[{{0}, {0}}]]
    end

    test "rule 255, k=1: only the all-ones fixed point" do
      cycles =
        ProductDeBruijnGraph.build(255, 1)
        |> ProductDeBruijnGraph.find_cycles()

      assert cycles == [[{{1}, {1}}]]
    end

    test "cycles are deduplicated (no two identical entries)" do
      cycles =
        ProductDeBruijnGraph.build(110, 2)
        |> ProductDeBruijnGraph.find_cycles()

      assert cycles == Enum.uniq(cycles)
    end

    test "each cycle is in canonical form (smallest node is first)" do
      cycles =
        ProductDeBruijnGraph.build(110, 2)
        |> ProductDeBruijnGraph.find_cycles()

      Enum.each(cycles, fn cycle ->
        min_node = Enum.min(cycle)

        assert List.first(cycle) == min_node,
               "Cycle not canonicalised: #{inspect(cycle)}"
      end)
    end

    test "cycles are non-empty" do
      cycles =
        ProductDeBruijnGraph.build(30, 2)
        |> ProductDeBruijnGraph.find_cycles()

      assert Enum.all?(cycles, fn c -> length(c) > 0 end)
    end
  end

  # ---------------------------------------------------------------------------
  # scc/1
  # ---------------------------------------------------------------------------

  describe "scc/1 – rule 0, k=1" do
    setup do
      {:ok, sccs: ProductDeBruijnGraph.build(0, 1) |> ProductDeBruijnGraph.scc()}
    end

    test "returns 3 SCCs (one per reachable node)", %{sccs: sccs} do
      # Reachable nodes in the rule-0 k=1 graph:
      # {{0},{0}}, {{0},{1}} (target-only), {{1},{0}} (source-only)
      assert length(sccs) == 3
    end

    test "every SCC is a singleton", %{sccs: sccs} do
      assert Enum.all?(sccs, fn scc -> length(scc) == 1 end)
    end

    test "the three nodes are covered exactly once", %{sccs: sccs} do
      nodes = sccs |> List.flatten() |> MapSet.new()

      assert nodes == MapSet.new([{{0}, {0}}, {{0}, {1}}, {{1}, {0}}])
    end
  end

  describe "scc/1 – rule 255, k=1" do
    setup do
      {:ok, sccs: ProductDeBruijnGraph.build(255, 1) |> ProductDeBruijnGraph.scc()}
    end

    test "returns 3 SCCs", %{sccs: sccs} do
      assert length(sccs) == 3
    end

    test "every SCC is a singleton", %{sccs: sccs} do
      assert Enum.all?(sccs, fn scc -> length(scc) == 1 end)
    end

    test "the three nodes are covered exactly once", %{sccs: sccs} do
      nodes = sccs |> List.flatten() |> MapSet.new()

      assert nodes == MapSet.new([{{0}, {1}}, {{1}, {0}}, {{1}, {1}}])
    end
  end

  describe "scc/1 – structural invariants" do
    test "every node in the graph appears in exactly one SCC" do
      graph = ProductDeBruijnGraph.build(110, 2)
      sccs = ProductDeBruijnGraph.scc(graph)

      all_nodes =
        Enum.flat_map(graph, fn {from, tos} -> [from | tos] end)
        |> MapSet.new()

      scc_nodes = sccs |> List.flatten() |> MapSet.new()

      assert scc_nodes == all_nodes
    end

    test "SCCs are disjoint" do
      graph = ProductDeBruijnGraph.build(110, 2)
      sccs = ProductDeBruijnGraph.scc(graph)
      all_members = sccs |> List.flatten()

      assert length(all_members) == length(Enum.uniq(all_members))
    end
  end

  # ---------------------------------------------------------------------------
  # adjacency_matrix/1
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # find_cycle/2
  # ---------------------------------------------------------------------------

  describe "find_cycle/2" do
    test "returns a non-empty list of nodes" do
      graph = ProductDeBruijnGraph.build(0, 1)
      # The single-node SCC {{0},{0}} has a self-loop under rule 0
      scc = [{{0}, {0}}]
      cycle = ProductDeBruijnGraph.find_cycle(graph, scc)
      assert is_list(cycle) and length(cycle) > 0
    end

    test "every node in the returned cycle belongs to the given SCC" do
      graph = ProductDeBruijnGraph.build(110, 2)
      [scc | _] = ProductDeBruijnGraph.scc(graph) |> Enum.filter(&(length(&1) > 1))
      cycle = ProductDeBruijnGraph.find_cycle(graph, scc)
      scc_set = MapSet.new(scc)
      assert Enum.all?(cycle, &MapSet.member?(scc_set, &1))
    end

    test "consecutive nodes in the cycle are connected by an edge" do
      graph = ProductDeBruijnGraph.build(110, 2)
      [scc | _] = ProductDeBruijnGraph.scc(graph) |> Enum.filter(&(length(&1) > 1))
      cycle = ProductDeBruijnGraph.find_cycle(graph, scc)

      cycle
      |> Enum.zip(tl(cycle) ++ [hd(cycle)])
      |> Enum.each(fn {from, to} ->
        assert to in Map.get(graph, from, []),
               "No edge #{inspect(from)} → #{inspect(to)} in graph"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # find_attractors/1
  # ---------------------------------------------------------------------------

  describe "find_attractors/1" do
    test "rule 0, k=1: one attractor (all-zeros fixed point)" do
      attractors =
        ProductDeBruijnGraph.build(0, 1)
        |> ProductDeBruijnGraph.find_attractors()

      assert length(attractors) == 1
    end

    test "rule 255, k=1: one attractor (all-ones fixed point)" do
      attractors =
        ProductDeBruijnGraph.build(255, 1)
        |> ProductDeBruijnGraph.find_attractors()

      assert length(attractors) == 1
    end

    test "each attractor is a non-empty list of nodes" do
      attractors =
        ProductDeBruijnGraph.build(110, 2)
        |> ProductDeBruijnGraph.find_attractors()

      assert Enum.all?(attractors, fn a -> is_list(a) and length(a) > 0 end)
    end

    test "nodes in every attractor cycle are valid graph nodes" do
      graph = ProductDeBruijnGraph.build(110, 2)
      all_nodes = Enum.flat_map(graph, fn {f, ts} -> [f | ts] end) |> MapSet.new()

      graph
      |> ProductDeBruijnGraph.find_attractors()
      |> Enum.each(fn cycle ->
        Enum.each(cycle, fn node ->
          assert MapSet.member?(all_nodes, node), "Unknown node in attractor: #{inspect(node)}"
        end)
      end)
    end

    test "consecutive nodes in every attractor cycle are connected by an edge" do
      graph = ProductDeBruijnGraph.build(110, 2)

      graph
      |> ProductDeBruijnGraph.find_attractors()
      |> Enum.each(fn cycle ->
        cycle
        |> Enum.zip(tl(cycle) ++ [hd(cycle)])
        |> Enum.each(fn {from, to} ->
          assert to in Map.get(graph, from, []),
                 "No edge #{inspect(from)} → #{inspect(to)} in attractor cycle"
        end)
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # to_spacetime_svg/2
  # ---------------------------------------------------------------------------

  describe "to_spacetime_svg/2" do
    test "returns a binary (SVG string)" do
      graph = ProductDeBruijnGraph.build(110, 2)
      attractors = ProductDeBruijnGraph.find_attractors(graph)
      svg = ProductDeBruijnGraph.to_spacetime_svg(graph, attractors)
      assert is_binary(svg)
    end

    test "output contains an <svg> root element" do
      graph = ProductDeBruijnGraph.build(110, 2)

      svg =
        ProductDeBruijnGraph.to_spacetime_svg(graph, ProductDeBruijnGraph.find_attractors(graph))

      assert svg =~ "<svg"
      assert svg =~ "</svg>"
    end

    test "output contains one <rect> per cell per attractor cycle" do
      graph = ProductDeBruijnGraph.build(0, 1)
      [cycle] = ProductDeBruijnGraph.find_attractors(graph)
      # k=1, cycle length=1 → 1 row × 1 col = 1 rect
      svg = ProductDeBruijnGraph.to_spacetime_svg(graph, [cycle])
      rect_count = svg |> String.split("<rect") |> length() |> Kernel.-(1)
      assert rect_count == length(cycle) * 1
    end

    test "rule 0, k=1: the single cell is white (dead)" do
      graph = ProductDeBruijnGraph.build(0, 1)
      [cycle] = ProductDeBruijnGraph.find_attractors(graph)
      svg = ProductDeBruijnGraph.to_spacetime_svg(graph, [cycle])
      # The unique attractor cell is dead (0), so its rect must have fill="white"
      assert svg =~ ~s|fill="white"|
    end

    test "rule 255, k=1: the single cell uses the cycle colour (alive)" do
      graph = ProductDeBruijnGraph.build(255, 1)
      [cycle] = ProductDeBruijnGraph.find_attractors(graph)
      svg = ProductDeBruijnGraph.to_spacetime_svg(graph, [cycle])
      # The cell is alive (1) so it must NOT be white — it gets the cycle colour
      refute svg =~ ~s|fill="white"|
    end

    test "empty cycles list produces an SVG with no rects" do
      graph = ProductDeBruijnGraph.build(110, 2)
      svg = ProductDeBruijnGraph.to_spacetime_svg(graph, [])
      refute svg =~ "<rect"
    end

    test "cell size option is reflected in rect dimensions" do
      graph = ProductDeBruijnGraph.build(0, 1)
      [cycle] = ProductDeBruijnGraph.find_attractors(graph)
      svg = ProductDeBruijnGraph.to_spacetime_svg(graph, [cycle], cell: 20)
      assert svg =~ ~s|width="20"|
      assert svg =~ ~s|height="20"|
    end
  end

  # ---------------------------------------------------------------------------
  # adjacency_matrix/1
  # ---------------------------------------------------------------------------

  describe "adjacency_matrix/1" do
    test "returns {nodes, matrix} tuple" do
      graph = ProductDeBruijnGraph.build(0, 1)
      result = ProductDeBruijnGraph.adjacency_matrix(graph)
      assert match?({nodes, matrix} when is_list(nodes) and is_list(matrix), result)
    end

    test "matrix dimensions equal the number of nodes" do
      graph = ProductDeBruijnGraph.build(110, 2)
      {nodes, matrix} = ProductDeBruijnGraph.adjacency_matrix(graph)
      n = length(nodes)
      assert length(matrix) == n
      assert Enum.all?(matrix, fn row -> length(row) == n end)
    end

    test "matrix entries are 0 or 1" do
      graph = ProductDeBruijnGraph.build(30, 2)
      {_, matrix} = ProductDeBruijnGraph.adjacency_matrix(graph)
      assert Enum.all?(List.flatten(matrix), fn v -> v == 0 or v == 1 end)
    end

    test "matrix reflects graph edges: matrix[i][j]=1 iff nodes[i]→nodes[j] exists" do
      graph = ProductDeBruijnGraph.build(0, 1)
      {nodes, matrix} = ProductDeBruijnGraph.adjacency_matrix(graph)
      index = nodes |> Enum.with_index() |> Map.new()

      Enum.each(graph, fn {from, tos} ->
        i = index[from]

        Enum.each(tos, fn to ->
          j = index[to]

          assert Enum.at(Enum.at(matrix, i), j) == 1,
                 "Expected matrix[#{i}][#{j}] == 1 for edge #{inspect(from)}→#{inspect(to)}"
        end)
      end)
    end
  end
end
