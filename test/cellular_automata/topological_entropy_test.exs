defmodule CellularAutomata.TopologicalEntropyTest do
  use ExUnit.Case, async: true

  alias CellularAutomata.{ProductDeBruijnGraph, TopologicalEntropy}

  # Allowed floating-point slop for entropy comparisons.
  @tol 1.0e-6

  defp graph(rule, k), do: ProductDeBruijnGraph.build(rule, k)
  defp entropy(rule, k), do: TopologicalEntropy.entropy(graph(rule, k))

  # ---------------------------------------------------------------------------
  # Zero-entropy rules
  # ---------------------------------------------------------------------------

  describe "entropy/1 – rule 0 (constant-0)" do
    test "k=1 entropy is 0" do
      assert_in_delta entropy(0, 1), 0.0, @tol
    end

    test "k=2 entropy is 0" do
      assert_in_delta entropy(0, 2), 0.0, @tol
    end

    test "k=3 entropy is 0" do
      assert_in_delta entropy(0, 3), 0.0, @tol
    end
  end

  describe "entropy/1 – rule 255 (constant-1)" do
    test "k=1 entropy is 0" do
      assert_in_delta entropy(255, 1), 0.0, @tol
    end

    test "k=2 entropy is 0" do
      assert_in_delta entropy(255, 2), 0.0, @tol
    end
  end

  describe "entropy/1 – rule 204 (identity / copy-centre)" do
    # Rule 204 is f(l,c,r) = c: every binary configuration is a fixed point.
    # There are 2^n valid spatial patterns of width n, so the spectral radius
    # equals 2 and entropy equals log(2).
    test "k=1 entropy equals log(2)" do
      assert_in_delta entropy(204, 1), :math.log(2), @tol
    end

    test "k=2 entropy equals log(2)" do
      assert_in_delta entropy(204, 2), :math.log(2), @tol
    end
  end

  # ---------------------------------------------------------------------------
  # Non-negativity
  # ---------------------------------------------------------------------------

  describe "entropy/1 – non-negativity" do
    # Topological entropy is always ≥ 0 because the spectral radius of a
    # non-negative integer matrix is ≥ 1 whenever the graph is connected.
    for rule <- [0, 30, 90, 110, 150, 255] do
      test "rule #{rule} k=2 entropy >= 0" do
        assert entropy(unquote(rule), 2) >= -@tol
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Rule 110
  # ---------------------------------------------------------------------------

  describe "entropy/1 – rule 110 (complex)" do
    # Rule 110 is Turing-complete; its product De Bruijn graph for k=2 has
    # period-2 cycles that produce strictly positive entropy.
    test "k=2 entropy is positive" do
      assert entropy(110, 2) > @tol
    end

    test "k=2 entropy is strictly greater than rule 0 k=2" do
      assert entropy(110, 2) > entropy(0, 2) + @tol
    end
  end

  # ---------------------------------------------------------------------------
  # Result is a finite float
  # ---------------------------------------------------------------------------

  describe "entropy/1 – return type" do
    test "returns a float for rule 0 k=1" do
      result = entropy(0, 1)
      assert is_float(result)
      assert result != :infinity
      assert result != :neg_infinity
      refute is_nan(result)
    end

    test "returns a float for rule 110 k=2" do
      result = entropy(110, 2)
      assert is_float(result)
      assert result != :infinity
      refute is_nan(result)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp is_nan(x), do: x != x
end
