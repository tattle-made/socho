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

  defp trial_with(plugin, config, children \\ []) do
    %Trial{plugin: plugin, node_type: "trial", config: config, children: children}
  end

  defp timeline_node(children, config \\ %{}) do
    %Trial{plugin: nil, node_type: "timeline", config: config, children: children}
  end

  defp template_group(children) do
    %Trial{plugin: nil, node_type: "template_group", config: %{}, children: children}
  end

  defp counterbalanced_group(children, config \\ %{}) do
    %Trial{plugin: nil, node_type: "counterbalanced_group", config: config, children: children}
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

  describe "emit_node/2 — regular trial" do
    test "returns counter+1, one declaration, and trial var name" do
      node = trial("html-keyboard-response")
      {new_counter, [decl], var_name} = JsGenerator.emit_node(node, 1)
      assert new_counter == 2
      assert var_name == "trial1"
      assert decl =~ "const trial1 ="
      assert decl =~ "type: jsPsychHtmlKeyboardResponse"
    end

    test "var name and counter use the given starting counter" do
      node = trial("html-keyboard-response")
      {new_counter, [_decl], var_name} = JsGenerator.emit_node(node, 5)
      assert new_counter == 6
      assert var_name == "trial5"
    end

    test "emits data_tag when present in config" do
      node = trial_with("html-keyboard-response", %{"data_tag" => "my_tag"})
      {_counter, [decl], _var} = JsGenerator.emit_node(node, 1)
      assert decl =~ "data: { data_tag: `my_tag` }"
    end

    test "omits data block when data_tag is absent" do
      node = trial("html-keyboard-response")
      {_counter, [decl], _var} = JsGenerator.emit_node(node, 1)
      refute decl =~ "data_tag"
    end

    test "emits extensions block when touchscreen-buttons is enabled" do
      node = %Trial{
        plugin: "html-keyboard-response",
        node_type: "trial",
        config: %{},
        children: [],
        extensions: %{"touchscreen-buttons" => %{"enabled" => true}}
      }
      {_counter, [decl], _var} = JsGenerator.emit_node(node, 1)
      assert decl =~ "extensions:"
      assert decl =~ "jsPsychExtensionTouchscreenButtons"
    end

    test "omits extensions block when touchscreen-buttons is disabled" do
      node = %Trial{
        plugin: "html-keyboard-response",
        node_type: "trial",
        config: %{},
        children: [],
        extensions: %{"touchscreen-buttons" => %{"enabled" => false}}
      }
      {_counter, [decl], _var} = JsGenerator.emit_node(node, 1)
      refute decl =~ "extensions:"
    end
  end

  describe "emit_node/2 — timeline" do
    test "empty timeline emits one decl with empty timeline array" do
      node = timeline_node([])
      {new_counter, [decl], var_name} = JsGenerator.emit_node(node, 1)
      assert new_counter == 2
      assert var_name == "timeline1"
      assert decl =~ "const timeline1 ="
      assert decl =~ "timeline: []"
    end

    test "child decls come before the timeline decl" do
      child = trial("html-keyboard-response")
      node = timeline_node([child])
      {new_counter, decls, var_name} = JsGenerator.emit_node(node, 1)
      assert new_counter == 3
      assert var_name == "timeline1"
      assert length(decls) == 2
      [child_decl, own_decl] = decls
      assert child_decl =~ "const trial2 ="
      assert own_decl =~ "const timeline1 ="
      assert own_decl =~ "trial2"
    end

    test "counter advances by the total number of nodes emitted" do
      children = [trial("html-keyboard-response"), trial("image-keyboard-response")]
      node = timeline_node(children)
      {new_counter, decls, _var} = JsGenerator.emit_node(node, 1)
      assert new_counter == 4
      assert length(decls) == 3
    end
  end

  describe "emit_node/2 — template_group" do
    test "emits timeline wrapper without trailing comma after array" do
      child = trial("html-keyboard-response")
      node = template_group([child])
      {_counter, decls, var_name} = JsGenerator.emit_node(node, 1)
      own_decl = List.last(decls)
      assert var_name == "timeline1"
      assert own_decl =~ "timeline: [trial2]"
      refute own_decl =~ "timeline: [trial2],"
    end

    test "counter and decl count behave like timeline" do
      node = template_group([trial("survey"), trial("html-keyboard-response")])
      {new_counter, decls, _var} = JsGenerator.emit_node(node, 1)
      assert new_counter == 4
      assert length(decls) == 3
    end
  end

  describe "emit_node/2 — counterbalanced_group" do
    test "emits an IIFE with random version selection" do
      children = [trial("html-keyboard-response"), trial("image-keyboard-response")]
      node = counterbalanced_group(children)
      {_counter, decls, var_name} = JsGenerator.emit_node(node, 1)
      own_decl = List.last(decls)
      assert var_name == "timeline1"
      assert own_decl =~ "Math.random()"
      assert own_decl =~ "versions"
    end

    test "splits children evenly by default" do
      children = [trial("a"), trial("b"), trial("c"), trial("d")]
      node = counterbalanced_group(children)
      {_counter, decls, _var} = JsGenerator.emit_node(node, 1)
      own_decl = List.last(decls)
      assert own_decl =~ "[trial2, trial3]"
      assert own_decl =~ "[trial4, trial5]"
    end

    test "respects group_sizes config" do
      children = [trial("a"), trial("b"), trial("c")]
      node = counterbalanced_group(children, %{"group_sizes" => [1, 2]})
      {_counter, decls, _var} = JsGenerator.emit_node(node, 1)
      own_decl = List.last(decls)
      assert own_decl =~ "[trial2]"
      assert own_decl =~ "[trial3, trial4]"
    end
  end

  describe "emit_node/2 — pairwise-compare" do
    test "emits a timeline var (not trial var)" do
      node = trial_with("pairwise-compare", %{"images" => []})
      {new_counter, [decl], var_name} = JsGenerator.emit_node(node, 1)
      assert new_counter == 2
      assert var_name == "timeline1"
      assert decl =~ "const timeline1 ="
    end

    test "includes jsPsychMultiImageSelect type" do
      node = trial_with("pairwise-compare", %{"images" => ["a.jpg", "b.jpg"]})
      {_counter, [decl], _var} = JsGenerator.emit_node(node, 1)
      assert decl =~ "jsPsychMultiImageSelect"
    end

    test "emits null prompt when prompt is absent" do
      node = trial_with("pairwise-compare", %{"images" => []})
      {_counter, [decl], _var} = JsGenerator.emit_node(node, 1)
      assert decl =~ "prompt: null"
    end

    test "emits template literal prompt when prompt is set" do
      node = trial_with("pairwise-compare", %{"images" => [], "prompt" => "Pick one"})
      {_counter, [decl], _var} = JsGenerator.emit_node(node, 1)
      assert decl =~ "prompt: `Pick one`"
    end

    test "emits data_tag when set" do
      node = trial_with("pairwise-compare", %{"images" => [], "data_tag" => "pw_round"})
      {_counter, [decl], _var} = JsGenerator.emit_node(node, 1)
      assert decl =~ "data: { data_tag: `pw_round` }"
    end

    test "uses default image dimensions when not specified" do
      node = trial_with("pairwise-compare", %{"images" => []})
      {_counter, [decl], _var} = JsGenerator.emit_node(node, 1)
      assert decl =~ "image_width: 300"
      assert decl =~ "image_height: 300"
    end
  end
end
