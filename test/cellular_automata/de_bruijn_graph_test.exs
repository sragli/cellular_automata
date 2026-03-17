defmodule CellularAutomata.DeBruijnGraphTest do
  use ExUnit.Case, async: true

  alias CellularAutomata.DeBruijnGraph

  # ---------------------------------------------------------------------------
  # build/1
  # ---------------------------------------------------------------------------

  describe "build/1" do
    test "returns exactly 4 nodes (all pairs of {0|1, 0|1})" do
      graph = DeBruijnGraph.build(0)

      assert map_size(graph) == 4
      assert Map.has_key?(graph, {0, 0})
      assert Map.has_key?(graph, {0, 1})
      assert Map.has_key?(graph, {1, 0})
      assert Map.has_key?(graph, {1, 1})
    end

    test "each node has exactly 2 outgoing edges" do
      for rule_id <- [0, 30, 110, 255] do
        graph = DeBruijnGraph.build(rule_id)

        assert Enum.all?(graph, fn {_, edges} -> length(edges) == 2 end),
               "Rule #{rule_id}: expected every node to have 2 edges"
      end
    end

    test "rule 0 labels every edge with 0" do
      graph = DeBruijnGraph.build(0)
      labels = graph |> Map.values() |> List.flatten() |> Enum.map(fn {_, l} -> l end)
      assert Enum.all?(labels, &(&1 == 0))
    end

    test "rule 255 labels every edge with 1" do
      graph = DeBruijnGraph.build(255)
      labels = graph |> Map.values() |> List.flatten() |> Enum.map(fn {_, l} -> l end)
      assert Enum.all?(labels, &(&1 == 1))
    end

    test "rule 110 edge labels match the rule table" do
      # Rule 110 = 0b01101110
      # pattern (abc) → bit position → output
      # 0 (000)→0, 1 (001)→1, 2 (010)→1, 3 (011)→1,
      # 4 (100)→0, 5 (101)→1, 6 (110)→1, 7 (111)→0
      graph = DeBruijnGraph.build(110)

      # Flatten to {from, to, label} triples for easy lookup
      triples =
        Enum.flat_map(graph, fn {from, edges} ->
          Enum.map(edges, fn {to, label} -> {from, to, label} end)
        end)

      assert {{0, 0}, {0, 0}, 0} in triples
      assert {{0, 0}, {0, 1}, 1} in triples
      assert {{0, 1}, {1, 0}, 1} in triples
      assert {{0, 1}, {1, 1}, 1} in triples
      assert {{1, 0}, {0, 0}, 0} in triples
      assert {{1, 0}, {0, 1}, 1} in triples
      assert {{1, 1}, {1, 0}, 1} in triples
      assert {{1, 1}, {1, 1}, 0} in triples
    end

    test "edge topology is the same for all rules" do
      topology = fn graph ->
        graph
        |> Enum.flat_map(fn {from, edges} -> Enum.map(edges, fn {to, _} -> {from, to} end) end)
        |> MapSet.new()
      end

      base = topology.(DeBruijnGraph.build(0))

      for rule_id <- [30, 90, 110, 184, 255] do
        assert topology.(DeBruijnGraph.build(rule_id)) == base,
               "Rule #{rule_id}: edge topology differs from rule 0"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # adjacency_matrix/1
  # ---------------------------------------------------------------------------

  describe "adjacency_matrix/1" do
    test "returns a 4×4 matrix" do
      matrix = DeBruijnGraph.adjacency_matrix(DeBruijnGraph.build(0))
      assert length(matrix) == 4
      assert Enum.all?(matrix, fn row -> length(row) == 4 end)
    end

    test "matrix values are the same for all rules" do
      # The adjacency matrix captures topology only (labels ignored),
      # which is identical for every ECA rule.
      # Nodes sorted: {0,0}→0, {0,1}→1, {1,0}→2, {1,1}→3
      # {0,0}→{0,0},{0,1}  {0,1}→{1,0},{1,1}  {1,0}→{0,0},{0,1}  {1,1}→{1,0},{1,1}
      expected = [
        [1, 1, 0, 0],
        [0, 0, 1, 1],
        [1, 1, 0, 0],
        [0, 0, 1, 1]
      ]

      for rule_id <- [0, 30, 110, 255] do
        assert DeBruijnGraph.adjacency_matrix(DeBruijnGraph.build(rule_id)) == expected,
               "Rule #{rule_id}: unexpected adjacency matrix"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # count_periodic_patterns/2
  # ---------------------------------------------------------------------------

  describe "count_periodic_patterns/2" do
    # trace(A^n) = 2^n for the ECA De Bruijn adjacency matrix, for all rules,
    # because the topology is fixed and equals the complete binary De Bruijn graph.
    test "returns 2 for period 1" do
      assert DeBruijnGraph.count_periodic_patterns(DeBruijnGraph.build(0), 1) == 2
    end

    test "returns 4 for period 2" do
      assert DeBruijnGraph.count_periodic_patterns(DeBruijnGraph.build(0), 2) == 4
    end

    test "returns 8 for period 3" do
      assert DeBruijnGraph.count_periodic_patterns(DeBruijnGraph.build(0), 3) == 8
    end

    test "returns 16 for period 4" do
      assert DeBruijnGraph.count_periodic_patterns(DeBruijnGraph.build(0), 4) == 16
    end

    test "count equals 2^n for all rules (topology-independent)" do
      for rule_id <- [30, 110, 255], n <- [1, 2, 3, 4] do
        assert DeBruijnGraph.count_periodic_patterns(DeBruijnGraph.build(rule_id), n) == 2 ** n,
               "Rule #{rule_id}, n=#{n}: expected #{2 ** n}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # find_cycles/1
  # ---------------------------------------------------------------------------

  describe "find_cycles/1" do
    test "contains self-loop for {0,0}" do
      cycles = DeBruijnGraph.build(0) |> DeBruijnGraph.find_cycles()
      # Self-loop: DFS returns [Enum.reverse([next | path])] where next==start==current
      # path=[{0,0}], [next|path]=[{0,0},{0,0}] → [{0,0},{0,0}]
      assert [{0, 0}, {0, 0}] in cycles
    end

    test "contains self-loop for {1,1}" do
      cycles = DeBruijnGraph.build(0) |> DeBruijnGraph.find_cycles()
      assert [{1, 1}, {1, 1}] in cycles
    end

    test "contains the length-2 cycle {0,1}↔{1,0} from both starting nodes" do
      cycles = DeBruijnGraph.build(0) |> DeBruijnGraph.find_cycles()
      # DeBruijnGraph does NOT deduplicate; the same physical cycle appears
      # once per member node, with that node at both ends.
      assert [{0, 1}, {1, 0}, {0, 1}] in cycles
      assert [{1, 0}, {0, 1}, {1, 0}] in cycles
    end

    test "all returned cycles are non-empty" do
      cycles = DeBruijnGraph.build(110) |> DeBruijnGraph.find_cycles()
      assert Enum.all?(cycles, fn c -> length(c) > 0 end)
    end

    test "every cycle starts and ends with the same node (closed representation)" do
      cycles = DeBruijnGraph.build(110) |> DeBruijnGraph.find_cycles()

      assert Enum.all?(cycles, fn cycle ->
               List.first(cycle) == List.last(cycle)
             end)
    end
  end
end
