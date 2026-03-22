defmodule CellularAutomata.AttractorNetworkTest do
  use ExUnit.Case, async: true

  alias CellularAutomata.{ProductDeBruijnGraph, AttractorNetwork}

  defp build(rule, k, opts \\ []) do
    graph = ProductDeBruijnGraph.build(rule, k)
    AttractorNetwork.build(graph, rule, opts)
  end

  # ---------------------------------------------------------------------------
  # Return shape
  # ---------------------------------------------------------------------------

  describe "build/3 – return shape" do
    test "returns a map with :attractors, :representatives, and :edges keys" do
      result = build(0, 1)
      assert is_map(result)
      assert Map.has_key?(result, :attractors)
      assert Map.has_key?(result, :representatives)
      assert Map.has_key?(result, :edges)
    end

    test "number of representatives equals number of attractors" do
      result = build(110, 2)
      assert length(result.representatives) == length(result.attractors)
    end

    test "edge map has one entry per attractor" do
      result = build(110, 2)
      assert map_size(result.edges) == length(result.attractors)
      assert map_size(result.edges) == length(result.representatives)
    end

    test "edge map keys are zero-based integer indices" do
      result = build(110, 2)
      expected_keys = MapSet.new(0..(length(result.attractors) - 1))
      assert MapSet.new(Map.keys(result.edges)) == expected_keys
    end
  end

  # ---------------------------------------------------------------------------
  # Rule 0 – single fixed point {all-zeros}
  # ---------------------------------------------------------------------------

  describe "build/3 – rule 0, k=1 (single zero-attractor)" do
    setup do
      {:ok, result: build(0, 1)}
    end

    test "has exactly one attractor", %{result: r} do
      assert length(r.attractors) == 1
    end

    test "representative is [0]", %{result: r} do
      assert r.representatives == [[0]]
    end

    test "attractor 0 maps to itself under single-bit perturbation", %{result: r} do
      # The only 1-cell perturbation of [0] is [1], which converges back to [0]
      # under rule 0 (everything goes to all-zeros).
      assert r.edges[0] == [0]
    end
  end

  describe "build/3 – rule 0, k=2" do
    test "still has exactly one attractor" do
      assert length(build(0, 2).attractors) == 1
    end

    test "attractor self-loops under perturbation" do
      assert build(0, 2).edges[0] == [0]
    end
  end

  # ---------------------------------------------------------------------------
  # Rule 255 – single fixed point {all-ones}
  # ---------------------------------------------------------------------------

  describe "build/3 – rule 255, k=1 (single one-attractor)" do
    setup do
      {:ok, result: build(255, 1)}
    end

    test "has exactly one attractor", %{result: r} do
      assert length(r.attractors) == 1
    end

    test "representative is [1]", %{result: r} do
      assert r.representatives == [[1]]
    end

    test "attractor self-loops under single-bit perturbation", %{result: r} do
      # Any 1-cell perturbation of [1] is [0], which under rule 255 goes back
      # to [1].
      assert r.edges[0] == [0]
    end
  end

  # ---------------------------------------------------------------------------
  # Rule 110 – two attractors, k=2
  # ---------------------------------------------------------------------------

  describe "build/3 – rule 110, k=2" do
    setup do
      {:ok, result: build(110, 2)}
    end

    test "has exactly two attractors", %{result: r} do
      assert length(r.attractors) == 2
    end

    test "representatives are [[1,1,1,0], [0]]", %{result: r} do
      assert r.representatives == [[1, 1, 1, 0], [0]]
    end

    test "each attractor only maps to itself (isolated basins)", %{result: r} do
      assert r.edges[0] == [0]
      assert r.edges[1] == [1]
    end
  end

  # ---------------------------------------------------------------------------
  # perturbations: :none – every attractor is a self-loop
  # ---------------------------------------------------------------------------

  describe "build/3 – perturbations: :none" do
    test "rule 110 k=2 – each attractor maps only to itself" do
      result = build(110, 2, perturbations: :none)
      assert result.edges[0] == [0]
      assert result.edges[1] == [1]
    end

    test "rule 110 k=3 – each attractor maps only to itself" do
      # With :none the identity basin mapping always holds, regardless of
      # how isolated the attractor is under single-bit perturbation.
      result = build(110, 3, perturbations: :none)
      assert result.edges[0] == [0]
      assert result.edges[1] == [1]
    end

    test "rule 0 k=2 – single attractor self-loops" do
      result = build(0, 2, perturbations: :none)
      assert result.edges[0] == [0]
    end
  end

  # ---------------------------------------------------------------------------
  # Structural invariants
  # ---------------------------------------------------------------------------

  describe "build/3 – structural invariants" do
    test "all edge target indices are valid attractor indices (rule 110 k=2)" do
      result = build(110, 2)
      valid = MapSet.new(0..(length(result.attractors) - 1))

      for {_src, targets} <- result.edges do
        for t <- targets do
          assert t in valid
        end
      end
    end

    test "edge values are lists of unique integers" do
      result = build(110, 2)

      for {_src, targets} <- result.edges do
        assert is_list(targets)
        assert targets == Enum.uniq(targets)
        assert Enum.all?(targets, &is_integer/1)
      end
    end

    test "representatives contain only 0s and 1s" do
      result = build(110, 2)

      for rep <- result.representatives do
        assert Enum.all?(rep, fn b -> b in [0, 1] end)
      end
    end
  end
end
