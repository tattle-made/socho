defmodule Socho.Studies.JsGeneratorTest do
  use ExUnit.Case, async: true

  alias Socho.Studies.JsGenerator
  alias Socho.Studies.Trial

  defp trial(plugin, children \\ []) do
    %Trial{plugin: plugin, node_type: "trial", config: %{}, children: children}
  end

  defp timeline(children) do
    %Trial{plugin: nil, node_type: "timeline", config: %{}, children: children}
  end

  describe "collect_plugins/1" do
    test "returns empty list for empty input" do
      assert JsGenerator.collect_plugins([]) == []
    end

    test "returns the plugin name for a single trial" do
      assert JsGenerator.collect_plugins([trial("html-keyboard-response")]) ==
               ["html-keyboard-response"]
    end

    test "maps pairwise-compare to multi-image-select" do
      assert JsGenerator.collect_plugins([trial("pairwise-compare")]) ==
               ["multi-image-select"]
    end

    test "returns empty list for a node with no plugin (e.g. timeline)" do
      assert JsGenerator.collect_plugins([timeline([])]) == []
    end

    test "collects plugins from multiple sibling nodes in order" do
      nodes = [trial("html-keyboard-response"), trial("image-keyboard-response")]
      assert JsGenerator.collect_plugins(nodes) == ["html-keyboard-response", "image-keyboard-response"]
    end

    test "collects plugins from nested children" do
      child1 = trial("survey")
      child2 = trial("image-keyboard-response")
      parent = timeline([child1, child2])
      assert JsGenerator.collect_plugins([parent]) == ["survey", "image-keyboard-response"]
    end

    test "parent plugin comes before child plugins" do
      child = trial("survey")
      parent = trial("html-keyboard-response", [child])
      assert JsGenerator.collect_plugins([parent]) == ["html-keyboard-response", "survey"]
    end

    test "does not deduplicate plugins" do
      nodes = [trial("html-keyboard-response"), trial("html-keyboard-response")]
      assert JsGenerator.collect_plugins(nodes) == ["html-keyboard-response", "html-keyboard-response"]
    end

    test "handles deeply nested children" do
      deep = trial("survey")
      mid = timeline([deep])
      top = timeline([mid])
      assert JsGenerator.collect_plugins([top]) == ["survey"]
    end

    test "handles nil children gracefully" do
      node = %Trial{plugin: "html-keyboard-response", node_type: "trial", config: %{}, children: nil}
      assert JsGenerator.collect_plugins([node]) == ["html-keyboard-response"]
    end
  end
end
