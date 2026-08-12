defmodule SochoWeb.StudyLive.BuilderComponentsTest do
  use SochoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias SochoWeb.StudyLive.BuilderComponents

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp trial_node(plugin, opts \\ []) do
    %{
      id: opts[:id] || 1,
      node_type: "trial",
      plugin: plugin,
      config: %{},
      children: []
    }
  end

  defp timeline_node(opts \\ []) do
    %{
      id: opts[:id] || 1,
      node_type: "timeline",
      plugin: nil,
      config: %{},
      children: opts[:children] || []
    }
  end

  defp template_group_node(opts \\ []) do
    %{
      id: opts[:id] || 1,
      node_type: "template_group",
      plugin: nil,
      config: %{"template_name" => opts[:name] || "My Template"},
      children: opts[:children] || []
    }
  end

  defp render_param_field(attrs) do
    defaults = %{param: "field", prefix: "config", spec: %{}, kind: :text, value: nil, trial_id: nil}
    render_component(&BuilderComponents.param_field/1, Map.merge(defaults, attrs))
  end

  defp render_node_block(node, opts \\ []) do
    render_component(&BuilderComponents.node_block/1,
      node: node,
      position: opts[:position] || 1,
      selected_id: opts[:selected_id]
    )
  end

  # ---------------------------------------------------------------------------
  # input_kind/1
  # ---------------------------------------------------------------------------

  describe "input_kind/1" do
    test "BOOL -> :bool" do
      assert BuilderComponents.input_kind(%{"type" => "BOOL"}) == :bool
    end

    test "INT -> :number" do
      assert BuilderComponents.input_kind(%{"type" => "INT"}) == :number
    end

    test "FLOAT -> :number" do
      assert BuilderComponents.input_kind(%{"type" => "FLOAT"}) == :number
    end

    test "HTML_STRING -> :html" do
      assert BuilderComponents.input_kind(%{"type" => "HTML_STRING"}) == :html
    end

    test "COMPLEX array -> :complex_array" do
      assert BuilderComponents.input_kind(%{"type" => "COMPLEX", "array" => true}) == :complex_array
    end

    test "OBJECT -> :json" do
      assert BuilderComponents.input_kind(%{"type" => "OBJECT"}) == :json
    end

    test "FUNCTION -> :skip" do
      assert BuilderComponents.input_kind(%{"type" => "FUNCTION"}) == :skip
    end

    test "TIMELINE -> :skip" do
      assert BuilderComponents.input_kind(%{"type" => "TIMELINE"}) == :skip
    end

    test "unknown type -> :text" do
      assert BuilderComponents.input_kind(%{"type" => "STRING"}) == :text
      assert BuilderComponents.input_kind(%{}) == :text
    end
  end

  # ---------------------------------------------------------------------------
  # param_field :html
  # ---------------------------------------------------------------------------

  describe "param_field :html" do
    test "registers TipTap hook under BuilderComponents module" do
      html = render_param_field(%{kind: :html, spec: %{"type" => "HTML_STRING"}, value: "<p>hi</p>"})
      # The hook name must resolve to this module — not Builder — so that the
      # colocated script in BuilderComponents is actually wired up.
      assert html =~ ~s(phx-hook="SochoWeb.StudyLive.BuilderComponents.TipTap")
    end

    test "passes string value to data-value" do
      html = render_param_field(%{kind: :html, spec: %{"type" => "HTML_STRING"}, value: "<p>hello</p>"})
      assert html =~ ~s(data-value="&lt;p&gt;hello&lt;/p&gt;")
    end

    test "uses first element when value is a list (e.g. instructions pages)" do
      html = render_param_field(%{kind: :html, spec: %{"type" => "HTML_STRING"}, value: ["<p>page one</p>", "<p>page two</p>"]})
      assert html =~ ~s(data-value="&lt;p&gt;page one&lt;/p&gt;")
      refute html =~ "page two"
    end

    test "handles nil value gracefully" do
      html = render_param_field(%{kind: :html, spec: %{"type" => "HTML_STRING"}, value: nil})
      assert html =~ ~s(data-value="")
    end

    test "renders phx-update=ignore to prevent LiveView clobbering the editor" do
      html = render_param_field(%{kind: :html, spec: %{"type" => "HTML_STRING"}, value: ""})
      assert html =~ ~s(phx-update="ignore")
    end
  end

  # ---------------------------------------------------------------------------
  # param_field :bool
  # ---------------------------------------------------------------------------

  describe "param_field :bool" do
    test "renders a checkbox input" do
      html = render_param_field(%{kind: :bool, spec: %{"type" => "BOOL"}, value: false})
      assert html =~ ~s(type="checkbox")
    end

    test "checkbox is checked when value is true" do
      html = render_param_field(%{kind: :bool, spec: %{"type" => "BOOL"}, value: true})
      assert html =~ "checked"
    end

    test "checkbox is checked when value is the string \"true\"" do
      html = render_param_field(%{kind: :bool, spec: %{"type" => "BOOL"}, value: "true"})
      assert html =~ "checked"
    end

    test "checkbox is not checked when value is false" do
      html = render_param_field(%{kind: :bool, spec: %{"type" => "BOOL"}, value: false})
      refute html =~ "checked"
    end

    test "includes a hidden input so unchecked submits false" do
      html = render_param_field(%{kind: :bool, spec: %{"type" => "BOOL"}, value: false})
      assert html =~ ~s(type="hidden")
      assert html =~ ~s(value="false")
    end
  end

  # ---------------------------------------------------------------------------
  # param_field :number
  # ---------------------------------------------------------------------------

  describe "param_field :number" do
    test "renders a number input" do
      html = render_param_field(%{kind: :number, spec: %{"type" => "INT"}, value: "5"})
      assert html =~ ~s(type="number")
    end

    test "step is 1 for INT" do
      html = render_param_field(%{kind: :number, spec: %{"type" => "INT"}, value: ""})
      assert html =~ ~s(step="1")
    end

    test "step is 0.01 for FLOAT" do
      html = render_param_field(%{kind: :number, spec: %{"type" => "FLOAT"}, value: ""})
      assert html =~ ~s(step="0.01")
    end

    test "renders the param name as label" do
      html = render_param_field(%{kind: :number, param: "repetitions", spec: %{"type" => "INT"}, value: ""})
      assert html =~ "repetitions"
    end
  end

  # ---------------------------------------------------------------------------
  # param_field :text (default catch-all)
  # ---------------------------------------------------------------------------

  describe "param_field :text" do
    test "renders a text input" do
      html = render_param_field(%{kind: :text, spec: %{"type" => "STRING"}, value: "hello"})
      assert html =~ ~s(type="text")
      assert html =~ ~s(value="hello")
    end

    test "joins list values with a comma" do
      html = render_param_field(%{kind: :text, spec: %{"type" => "STRING", "array" => true}, value: ["a", "b", "c"]})
      assert html =~ ~s(value="a, b, c")
    end

    test "renders empty string for nil value" do
      html = render_param_field(%{kind: :text, spec: %{"type" => "STRING"}, value: nil})
      assert html =~ ~s(value="")
    end

    test "shows comma-separated placeholder hint for array types" do
      html = render_param_field(%{kind: :text, spec: %{"type" => "STRING", "array" => true}, value: nil})
      assert html =~ "comma-separated"
    end
  end

  # ---------------------------------------------------------------------------
  # param_field :complex_array
  # ---------------------------------------------------------------------------

  describe "param_field :complex_array" do
    test "renders a fieldset with the param name" do
      html = render_param_field(%{
        kind: :complex_array,
        param: "questions",
        spec: %{"type" => "COMPLEX", "array" => true, "nested" => %{}},
        value: []
      })
      assert html =~ "<fieldset"
      assert html =~ "questions"
    end

    test "renders an Add item button" do
      html = render_param_field(%{
        kind: :complex_array,
        param: "questions",
        spec: %{"type" => "COMPLEX", "array" => true, "nested" => %{}},
        value: []
      })
      assert html =~ "Add item"
    end

    test "renders one item row per entry in value" do
      html = render_param_field(%{
        kind: :complex_array,
        param: "questions",
        spec: %{"type" => "COMPLEX", "array" => true, "nested" => %{"prompt" => %{"type" => "STRING"}}},
        value: [%{"prompt" => "Q1"}, %{"prompt" => "Q2"}]
      })
      assert html =~ "Item 1"
      assert html =~ "Item 2"
    end
  end

  # ---------------------------------------------------------------------------
  # node_block — trial
  # ---------------------------------------------------------------------------

  describe "node_block trial" do
    test "renders the plugin name" do
      html = render_node_block(trial_node("html-button-response"))
      assert html =~ "html-button-response"
    end

    test "applies selected highlight when node is selected" do
      node = trial_node("survey", id: 42)
      html = render_node_block(node, selected_id: 42)
      assert html =~ "border-primary"
    end

    test "does not apply selected highlight when another node is selected" do
      node = trial_node("survey", id: 42)
      html = render_node_block(node, selected_id: 99)
      refute html =~ "border-primary"
    end

    test "renders move up and move down buttons" do
      html = render_node_block(trial_node("html-button-response"))
      assert html =~ "move_trial_up"
      assert html =~ "move_trial_down"
    end

    test "renders remove button" do
      html = render_node_block(trial_node("html-button-response"))
      assert html =~ "remove_trial"
    end
  end

  # ---------------------------------------------------------------------------
  # node_block — timeline
  # ---------------------------------------------------------------------------

  describe "node_block timeline" do
    test "renders TL badge" do
      html = render_node_block(timeline_node())
      assert html =~ ">TL<"
    end

    test "applies selected highlight when node is selected" do
      node = timeline_node(id: 10)
      html = render_node_block(node, selected_id: 10)
      assert html =~ "border-secondary"
    end

    test "shows empty state hint when no children" do
      html = render_node_block(timeline_node(children: []))
      assert html =~ "Select this group"
    end

    test "renders children recursively" do
      child = trial_node("survey", id: 2)
      html = render_node_block(timeline_node(children: [child]))
      assert html =~ "survey"
    end
  end

  # ---------------------------------------------------------------------------
  # node_block — template_group
  # ---------------------------------------------------------------------------

  describe "node_block template_group" do
    test "renders TPL badge" do
      html = render_node_block(template_group_node())
      assert html =~ ">TPL<"
    end

    test "renders the template name" do
      html = render_node_block(template_group_node(name: "Consent Gate"))
      assert html =~ "Consent Gate"
    end

    test "applies selected highlight when node is selected" do
      node = template_group_node(id: 5)
      html = render_node_block(node, selected_id: 5)
      assert html =~ "border-accent"
    end

    test "renders children recursively" do
      child = trial_node("instructions", id: 3)
      html = render_node_block(template_group_node(children: [child]))
      assert html =~ "instructions"
    end
  end
end
