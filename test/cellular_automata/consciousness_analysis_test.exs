defmodule CellularAutomata.ConsciousnessAnalysisTest do
  use ExUnit.Case, async: true

  alias CellularAutomata.ConsciousnessAnalysis
  alias CellularAutomata.ConsciousnessAnalysis.{AttractorReport, NodeState}
  alias CellularAutomata.ProductDeBruijnGraph

  # Canonical node labels for hand-crafted graph fixtures.
  # Each label is a 2-tuple matching the {a, b} structure of product De Bruijn nodes.
  @a {{0}, {0}}
  @b {{0}, {1}}
  @c {{1}, {0}}
  @d {{1}, {1}}

  # ---------------------------------------------------------------------------
  # induced_subgraph/2
  # ---------------------------------------------------------------------------

  describe "induced_subgraph/2" do
    test "excludes nodes outside the set" do
      graph = %{@a => [@b, @c], @b => [@a]}
      sub = ConsciousnessAnalysis.induced_subgraph(graph, MapSet.new([@a, @b]))
      refute Map.has_key?(sub, @c)
    end

    test "keeps nodes that are in the set" do
      graph = %{@a => [@b], @b => [@a]}
      sub = ConsciousnessAnalysis.induced_subgraph(graph, MapSet.new([@a, @b]))
      assert Map.has_key?(sub, @a)
      assert Map.has_key?(sub, @b)
    end

    test "removes edges pointing outside the set" do
      graph = %{@a => [@b, @c], @b => [@a]}
      sub = ConsciousnessAnalysis.induced_subgraph(graph, MapSet.new([@a, @b]))
      assert sub[@a] == [@b]
    end

    test "preserves internal edges" do
      graph = %{@a => [@b], @b => [@c], @c => [@a]}
      sub = ConsciousnessAnalysis.induced_subgraph(graph, MapSet.new([@a, @b, @c]))
      assert @b in sub[@a]
      assert @c in sub[@b]
      assert @a in sub[@c]
    end

    test "empty node set produces empty subgraph" do
      graph = %{@a => [@b]}
      sub = ConsciousnessAnalysis.induced_subgraph(graph, MapSet.new())
      assert sub == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # reachable_within/2
  # ---------------------------------------------------------------------------

  describe "reachable_within/2" do
    test "start node is always included" do
      assert MapSet.member?(ConsciousnessAnalysis.reachable_within(%{}, @a), @a)
    end

    test "self-loop: only the node itself is reachable" do
      sub = %{@a => [@a]}
      assert MapSet.equal?(ConsciousnessAnalysis.reachable_within(sub, @a), MapSet.new([@a]))
    end

    test "chain: start can reach both nodes" do
      sub = %{@a => [@b], @b => []}
      assert MapSet.equal?(ConsciousnessAnalysis.reachable_within(sub, @a), MapSet.new([@a, @b]))
    end

    test "chain: end node only reaches itself" do
      sub = %{@a => [@b], @b => []}
      assert MapSet.equal?(ConsciousnessAnalysis.reachable_within(sub, @b), MapSet.new([@b]))
    end

    test "triangle: all three nodes reachable from any start" do
      sub = %{@a => [@b], @b => [@c], @c => [@a]}
      full = MapSet.new([@a, @b, @c])
      assert MapSet.equal?(ConsciousnessAnalysis.reachable_within(sub, @a), full)
      assert MapSet.equal?(ConsciousnessAnalysis.reachable_within(sub, @b), full)
      assert MapSet.equal?(ConsciousnessAnalysis.reachable_within(sub, @c), full)
    end
  end

  # ---------------------------------------------------------------------------
  # scc/1
  # ---------------------------------------------------------------------------

  describe "scc/1" do
    test "single self-loop is its own SCC" do
      graph = %{@a => [@a]}
      sccs = ConsciousnessAnalysis.scc(graph)
      assert length(sccs) == 1
      assert [@a] in sccs
    end

    test "2-cycle forms one SCC containing both nodes" do
      graph = %{@a => [@b], @b => [@a]}
      [scc] = ConsciousnessAnalysis.scc(graph)
      assert MapSet.equal?(MapSet.new(scc), MapSet.new([@a, @b]))
    end

    test "triangle forms one SCC containing all three nodes" do
      graph = %{@a => [@b], @b => [@c], @c => [@a]}
      [scc] = ConsciousnessAnalysis.scc(graph)
      assert MapSet.equal?(MapSet.new(scc), MapSet.new([@a, @b, @c]))
    end

    test "two independent 2-cycles produce two SCCs" do
      graph = %{@a => [@b], @b => [@a], @c => [@d], @d => [@c]}
      sccs = ConsciousnessAnalysis.scc(graph)
      assert length(sccs) == 2
      scc_sets = Enum.map(sccs, &MapSet.new/1)
      assert MapSet.new([@a, @b]) in scc_sets
      assert MapSet.new([@c, @d]) in scc_sets
    end

    test "linear chain produces three singleton SCCs" do
      graph = %{@a => [@b], @b => [@c]}
      sccs = ConsciousnessAnalysis.scc(graph)
      assert length(sccs) == 3
      scc_sets = Enum.map(sccs, &MapSet.new/1)
      assert MapSet.new([@a]) in scc_sets
      assert MapSet.new([@b]) in scc_sets
      assert MapSet.new([@c]) in scc_sets
    end
  end

  # ---------------------------------------------------------------------------
  # find_cycle/2
  # ---------------------------------------------------------------------------

  describe "find_cycle/2" do
    test "self-loop SCC returns a single-element cycle" do
      graph = %{@a => [@a]}
      assert ConsciousnessAnalysis.find_cycle(graph, [@a]) == [@a]
    end

    test "2-cycle SCC returns both nodes" do
      graph = %{@a => [@b], @b => [@a]}
      cycle = ConsciousnessAnalysis.find_cycle(graph, [@a, @b])
      assert length(cycle) == 2
      assert MapSet.equal?(MapSet.new(cycle), MapSet.new([@a, @b]))
    end

    test "triangle SCC: consecutive nodes are connected by a graph edge" do
      graph = %{@a => [@b], @b => [@c], @c => [@a]}
      cycle = ConsciousnessAnalysis.find_cycle(graph, [@a, @b, @c])

      cycle
      |> Enum.zip(tl(cycle) ++ [hd(cycle)])
      |> Enum.each(fn {from, to} ->
        assert to in Map.get(graph, from, []),
               "No edge #{inspect(from)} → #{inspect(to)}"
      end)
    end

    test "all returned nodes belong to the given SCC" do
      graph = %{@a => [@b], @b => [@c], @c => [@a]}
      scc = [@a, @b, @c]
      cycle = ConsciousnessAnalysis.find_cycle(graph, scc)
      scc_set = MapSet.new(scc)
      assert Enum.all?(cycle, &MapSet.member?(scc_set, &1))
    end
  end

  # ---------------------------------------------------------------------------
  # feedback_strength/2
  # ---------------------------------------------------------------------------

  describe "feedback_strength/2" do
    test "self-loop gives 1.0" do
      sub = %{@a => [@a]}
      assert ConsciousnessAnalysis.feedback_strength([@a], sub) == 1.0
    end

    test "all nodes on a 2-cycle gives 1.0" do
      sub = %{@a => [@b], @b => [@a]}
      assert ConsciousnessAnalysis.feedback_strength([@a, @b], sub) == 1.0
    end

    test "all nodes on a triangle gives 1.0" do
      sub = %{@a => [@b], @b => [@c], @c => [@a]}
      assert ConsciousnessAnalysis.feedback_strength([@a, @b, @c], sub) == 1.0
    end

    test "result is in [0, 1]" do
      sub = %{@a => [@b], @b => [@a]}
      result = ConsciousnessAnalysis.feedback_strength([@a, @b], sub)
      assert result >= 0.0 and result <= 1.0
    end
  end

  # ---------------------------------------------------------------------------
  # observability/1
  # ---------------------------------------------------------------------------

  describe "observability/1" do
    test "empty subgraph gives 0.0" do
      assert ConsciousnessAnalysis.observability(%{}) == 0.0
    end

    test "all nodes with identical neighbour lists gives 1/n" do
      # @a and @b both point only to @c → identical pattern
      sub = %{@a => [@c], @b => [@c]}
      assert_in_delta ConsciousnessAnalysis.observability(sub), 0.5, 1.0e-9
    end

    test "all nodes with distinct neighbour lists gives 1.0" do
      sub = %{@a => [@b], @b => [@c], @c => [@a]}
      assert ConsciousnessAnalysis.observability(sub) == 1.0
    end

    test "result is in [0, 1]" do
      sub = %{@a => [@b], @b => [@a]}
      result = ConsciousnessAnalysis.observability(sub)
      assert result >= 0.0 and result <= 1.0
    end
  end

  # ---------------------------------------------------------------------------
  # differentiated_dynamics?/2
  # ---------------------------------------------------------------------------

  describe "differentiated_dynamics?/2" do
    test "returns false when all nodes have the same reachability set" do
      # Balanced 2-cycle: both nodes reach {a, b}
      sub = %{@a => [@b], @b => [@a]}
      refute ConsciousnessAnalysis.differentiated_dynamics?([@a, @b], sub)
    end

    test "returns true when nodes have distinct reachability sets" do
      # a→b with no back edge: reachable(@a) = {a,b}, reachable(@b) = {b}
      sub = %{@a => [@b], @b => []}
      assert ConsciousnessAnalysis.differentiated_dynamics?([@a, @b], sub)
    end
  end

  # ---------------------------------------------------------------------------
  # transfer_entropy/1
  # ---------------------------------------------------------------------------

  describe "transfer_entropy/1" do
    test "empty transitions gives 0.0" do
      ns = %NodeState{transitions: %{}, a: nil, b: nil, self_model: nil}
      assert ConsciousnessAnalysis.transfer_entropy(ns) == 0.0
    end

    test "single deterministic successor gives 0.0" do
      ns = %NodeState{transitions: %{@a => 1.0}, a: nil, b: nil, self_model: nil}
      assert_in_delta ConsciousnessAnalysis.transfer_entropy(ns), 0.0, 1.0e-9
    end

    test "two uniform successors gives 0.0 (uniform is the baseline)" do
      ns = %NodeState{transitions: %{@a => 0.5, @b => 0.5}, a: nil, b: nil, self_model: nil}
      assert_in_delta ConsciousnessAnalysis.transfer_entropy(ns), 0.0, 1.0e-9
    end

    test "non-uniform distribution gives positive TE" do
      ns = %NodeState{transitions: %{@a => 0.9, @b => 0.1}, a: nil, b: nil, self_model: nil}
      assert ConsciousnessAnalysis.transfer_entropy(ns) > 0.0
    end

    test "TE is non-negative" do
      ns = %NodeState{
        transitions: %{@a => 0.7, @b => 0.2, @c => 0.1},
        a: nil,
        b: nil,
        self_model: nil
      }

      assert ConsciousnessAnalysis.transfer_entropy(ns) >= 0.0
    end
  end

  # ---------------------------------------------------------------------------
  # mean_transfer_entropy/1
  # ---------------------------------------------------------------------------

  describe "mean_transfer_entropy/1" do
    test "empty list gives 0.0" do
      assert ConsciousnessAnalysis.mean_transfer_entropy([]) == 0.0
    end

    test "all-uniform nodes gives 0.0" do
      ns1 = %NodeState{transitions: %{@a => 0.5, @b => 0.5}, a: nil, b: nil, self_model: nil}
      ns2 = %NodeState{transitions: %{@a => 0.5, @b => 0.5}, a: nil, b: nil, self_model: nil}
      assert_in_delta ConsciousnessAnalysis.mean_transfer_entropy([ns1, ns2]), 0.0, 1.0e-9
    end

    test "mean lies between 0 and the max individual TE" do
      ns_zero = %NodeState{transitions: %{@a => 0.5, @b => 0.5}, a: nil, b: nil, self_model: nil}
      ns_pos = %NodeState{transitions: %{@a => 0.9, @b => 0.1}, a: nil, b: nil, self_model: nil}
      max_te = ConsciousnessAnalysis.transfer_entropy(ns_pos)
      mean_te = ConsciousnessAnalysis.mean_transfer_entropy([ns_zero, ns_pos])
      assert mean_te > 0.0
      assert mean_te < max_te
    end
  end

  # ---------------------------------------------------------------------------
  # enrich_nodes/2
  # ---------------------------------------------------------------------------

  describe "enrich_nodes/2" do
    test "returns one NodeState per cycle node" do
      sub = %{@a => [@b], @b => [@a]}
      assert length(ConsciousnessAnalysis.enrich_nodes([@a, @b], sub)) == 2
    end

    test "NodeState.a and .b match the node's tuple components" do
      sub = %{@a => [@b]}
      [ns] = ConsciousnessAnalysis.enrich_nodes([@a], sub)
      {expected_a, expected_b} = @a
      assert ns.a == expected_a
      assert ns.b == expected_b
    end

    test "transitions are uniform over successors" do
      sub = %{@a => [@b, @c]}
      [ns] = ConsciousnessAnalysis.enrich_nodes([@a], sub)
      assert_in_delta ns.transitions[@b], 0.5, 1.0e-9
      assert_in_delta ns.transitions[@c], 0.5, 1.0e-9
    end

    test "node with no successors has empty transitions" do
      sub = %{@a => []}
      [ns] = ConsciousnessAnalysis.enrich_nodes([@a], sub)
      assert ns.transitions == %{}
    end

    test "self_model.out_degree matches successor count" do
      sub = %{@a => [@b, @c]}
      [ns] = ConsciousnessAnalysis.enrich_nodes([@a], sub)
      assert ns.self_model.out_degree == 2
    end

    test "self_model.in_degree counts incoming edges within subgraph" do
      # @b receives edges from both @a and @c
      sub = %{@a => [@b], @c => [@b], @b => [@a]}
      node_states = ConsciousnessAnalysis.enrich_nodes([@a, @b, @c], sub)
      ns_b = Enum.find(node_states, fn ns -> {ns.a, ns.b} == @b end)
      assert ns_b.self_model.in_degree == 2
    end

    test "self_model.reachable includes the node itself" do
      sub = %{@a => [@b], @b => [@a]}
      [ns | _] = ConsciousnessAnalysis.enrich_nodes([@a, @b], sub)
      assert MapSet.member?(ns.self_model.reachable, @a)
    end

    test "self_model.loop_lengths detects a direct self-loop" do
      sub = %{@a => [@a]}
      [ns] = ConsciousnessAnalysis.enrich_nodes([@a], sub)
      assert Map.has_key?(ns.self_model.loop_lengths, 1)
    end

    test "self_model.loop_lengths detects a 2-cycle" do
      sub = %{@a => [@b], @b => [@a]}
      node_states = ConsciousnessAnalysis.enrich_nodes([@a, @b], sub)

      Enum.each(node_states, fn ns ->
        assert Map.has_key?(ns.self_model.loop_lengths, 2)
      end)
    end

    test "self_model.loop_lengths is empty for a node on no cycle" do
      # chain: @a → @b with no back edge, so @a cannot return to itself
      sub = %{@a => [@b], @b => []}
      [ns_a | _] = ConsciousnessAnalysis.enrich_nodes([@a, @b], sub)
      assert ns_a.self_model.loop_lengths == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # fixed_point_distance/1
  # ---------------------------------------------------------------------------

  describe "fixed_point_distance/1" do
    test "self-looping node is a perfect fixed point of ξ" do
      sub = %{@a => [@a]}
      [ns] = ConsciousnessAnalysis.enrich_nodes([@a], sub)
      assert_in_delta ConsciousnessAnalysis.fixed_point_distance(ns, sub), 0.0, 1.0e-9
    end

    test "every node in a balanced 2-cycle has distance 0.0" do
      sub = %{@a => [@b], @b => [@a]}
      node_states = ConsciousnessAnalysis.enrich_nodes([@a, @b], sub)

      Enum.each(node_states, fn ns ->
        assert_in_delta ConsciousnessAnalysis.fixed_point_distance(ns, sub), 0.0, 1.0e-9
      end)
    end

    test "result is non-negative" do
      sub = %{@a => [@b], @b => [@c], @c => [@a]}
      [ns | _] = ConsciousnessAnalysis.enrich_nodes([@a, @b, @c], sub)
      assert ConsciousnessAnalysis.fixed_point_distance(ns, sub) >= 0.0
    end
  end

  # ---------------------------------------------------------------------------
  # mean_fixed_point_distance/2
  # ---------------------------------------------------------------------------

  describe "mean_fixed_point_distance/2" do
    test "empty list returns 1.0 (worst-case sentinel)" do
      assert ConsciousnessAnalysis.mean_fixed_point_distance([], %{}) == 1.0
    end

    test "self-consistent nodes return 0.0" do
      sub = %{@a => [@a]}
      node_states = ConsciousnessAnalysis.enrich_nodes([@a], sub)

      assert_in_delta ConsciousnessAnalysis.mean_fixed_point_distance(node_states, sub),
                      0.0,
                      1.0e-9
    end

    test "result is in [0, 1]" do
      sub = %{@a => [@b], @b => [@a]}
      node_states = ConsciousnessAnalysis.enrich_nodes([@a, @b], sub)
      result = ConsciousnessAnalysis.mean_fixed_point_distance(node_states, sub)
      assert result >= 0.0 and result <= 1.0
    end
  end

  # ---------------------------------------------------------------------------
  # consciousness_score/5
  # ---------------------------------------------------------------------------

  describe "consciousness_score/5" do
    test "all-perfect inputs yield 1.0" do
      assert_in_delta ConsciousnessAnalysis.consciousness_score(1.0, 1.0, 1.0, 0.0, 0.05),
                      1.0,
                      1.0e-9
    end

    test "all-zero inputs yield 0.0" do
      assert_in_delta ConsciousnessAnalysis.consciousness_score(0.0, 0.0, 0.0, 1.0, 0.05),
                      0.0,
                      1.0e-9
    end

    test "mid-range inputs yield ~0.5" do
      score = ConsciousnessAnalysis.consciousness_score(0.5, 0.5, 0.5, 0.025, 0.05)
      assert_in_delta score, 0.5, 1.0e-9
    end

    test "out-of-range inputs are clamped: result stays in [0, 1]" do
      score = ConsciousnessAnalysis.consciousness_score(2.0, -1.0, 2.0, -0.1, 0.05)
      assert score >= 0.0 and score <= 1.0
    end
  end

  # ---------------------------------------------------------------------------
  # find_attractors/1
  # ---------------------------------------------------------------------------

  describe "find_attractors/1" do
    test "self-loop node is an attractor" do
      graph = %{@a => [@a]}
      [cycle] = ConsciousnessAnalysis.find_attractors(graph)
      assert @a in cycle
    end

    test "transient-only node is not an attractor" do
      # @c → @a is a transient; only the @a ↔ @b cycle counts
      graph = %{@a => [@b], @b => [@a], @c => [@a]}
      assert length(ConsciousnessAnalysis.find_attractors(graph)) == 1
    end

    test "two independent cycles produce two attractors" do
      graph = %{@a => [@b], @b => [@a], @c => [@d], @d => [@c]}
      assert length(ConsciousnessAnalysis.find_attractors(graph)) == 2
    end

    test "each attractor cycle has consecutive nodes connected by edges" do
      graph = %{@a => [@b], @b => [@c], @c => [@a]}
      [cycle] = ConsciousnessAnalysis.find_attractors(graph)

      cycle
      |> Enum.zip(tl(cycle) ++ [hd(cycle)])
      |> Enum.each(fn {from, to} ->
        assert to in Map.get(graph, from, [])
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # analyse/2 — integration
  # ---------------------------------------------------------------------------

  describe "analyse/2 – hand-crafted graph" do
    test "default min_size=2 excludes a single-node self-loop" do
      graph = %{@a => [@a]}
      assert ConsciousnessAnalysis.analyse(graph) == []
    end

    test "min_size: 1 includes the single-node self-loop" do
      graph = %{@a => [@a]}
      assert length(ConsciousnessAnalysis.analyse(graph, min_size: 1)) == 1
    end

    test "returns AttractorReport structs" do
      graph = %{@a => [@b], @b => [@a]}
      [report] = ConsciousnessAnalysis.analyse(graph, min_size: 2)
      assert match?(%AttractorReport{}, report)
    end

    test "report size matches cycle length" do
      graph = %{@a => [@b], @b => [@a]}
      [report] = ConsciousnessAnalysis.analyse(graph, min_size: 2)
      assert report.size == length(report.cycle)
    end

    test "node_states length matches cycle length" do
      graph = %{@a => [@b], @b => [@a]}
      [report] = ConsciousnessAnalysis.analyse(graph, min_size: 2)
      assert length(report.node_states) == report.size
    end

    test "consciousness_score is in [0, 1]" do
      graph = %{@a => [@b], @b => [@a]}
      [report] = ConsciousnessAnalysis.analyse(graph, min_size: 2)
      assert report.consciousness_score >= 0.0 and report.consciousness_score <= 1.0
    end
  end

  describe "analyse/2 – rule 110, k=2 integration" do
    setup do
      {:ok, graph: ProductDeBruijnGraph.build(110, 2)}
    end

    test "returns a non-empty list of AttractorReport structs", %{graph: g} do
      reports = ConsciousnessAnalysis.analyse(g)
      assert reports != []
      assert Enum.all?(reports, &match?(%AttractorReport{}, &1))
    end

    test "reports are sorted by consciousness_score descending", %{graph: g} do
      scores = g |> ConsciousnessAnalysis.analyse() |> Enum.map(& &1.consciousness_score)
      assert scores == Enum.sort(scores, :desc)
    end

    test "min_size option excludes cycles shorter than the threshold", %{graph: g} do
      reports = ConsciousnessAnalysis.analyse(g, min_size: 4)
      assert Enum.all?(reports, &(&1.size >= 4))
    end

    test "every report's size matches its cycle length", %{graph: g} do
      ConsciousnessAnalysis.analyse(g)
      |> Enum.each(fn r -> assert r.size == length(r.cycle) end)
    end

    test "consciousness_score is in [0, 1] for all reports", %{graph: g} do
      ConsciousnessAnalysis.analyse(g)
      |> Enum.each(fn r ->
        assert r.consciousness_score >= 0.0 and r.consciousness_score <= 1.0
      end)
    end

    test "feedback is in [0, 1] for all reports", %{graph: g} do
      ConsciousnessAnalysis.analyse(g)
      |> Enum.each(fn r ->
        assert r.feedback >= 0.0 and r.feedback <= 1.0
      end)
    end

    test "node_states length matches cycle length for all reports", %{graph: g} do
      ConsciousnessAnalysis.analyse(g)
      |> Enum.each(fn r ->
        assert length(r.node_states) == r.size
      end)
    end
  end
end
