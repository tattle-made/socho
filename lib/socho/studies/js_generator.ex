defmodule Socho.Studies.JsGenerator do
  @moduledoc "Generates jsPsych HTML page assets from a Study with preloaded trials."

  alias Socho.Studies.Registry

  @jspsych_base "/vendor/jspsych"
  @custom_base "/vendor/custom"

  def required_stylesheets(study) do
    survey_css =
      if "survey" in collect_plugins(study.trials),
        do: ["#{@jspsych_base}/survey.css"],
        else: []

    ["#{@jspsych_base}/jspsych.css"] ++ survey_css
  end

  def required_inline_css(study) do
    plugins = collect_plugins(study.trials)

    tsb_css =
      if collect_tsb_layouts(study.trials) != [] do
        """
        .jsTouchButton {
          position: fixed;
          z-index: 1000;
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
          user-select: none;
          -webkit-user-select: none;
          touch-action: none;
          font-size: 6vw;
          background: rgba(255, 155, 145, 0.15);
          box-shadow: none !important;
        }
        .jsTouchButtonLeft   { left: 0;  top: 0; width: 30%; height: 100%; }
        .jsTouchButtonRight  { right: 0; top: 0; width: 30%; height: 100%; }
        .jsTouchButtonLeftBottom  { left: 0;  bottom: 0; width: 35%; height: 35%; }
        .jsTouchButtonRightBottom { right: 0; bottom: 0; width: 35%; height: 35%; }
        .jsTouchButtonLeftTop     { left: 0;  top: 0;    width: 35%; height: 35%; }
        .jsTouchButtonRightTop    { right: 0; top: 0;    width: 35%; height: 35%; }
        .jsTouchButtonFillBottom,
        .jsTouchButtonLeftMiddle,
        .jsTouchButtonRightMiddle {
          position: fixed;
          z-index: 1000;
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
          user-select: none;
          -webkit-user-select: none;
          touch-action: none;
          font-size: 6vw;
          background: rgba(255, 155, 145, 0.15);
          box-shadow: none !important;
        }
        .jsTouchButtonFillBottom  { left: 0; bottom: 0; width: 100%; height: 20%; }
        .jsTouchButtonLeftMiddle  { left: 0;  top: 30%; width: 30%; height: 40%; }
        .jsTouchButtonRightMiddle { right: 0; top: 30%; width: 30%; height: 40%; }
        """
      else
        ""
      end

    iat_css =
      if "iat-image" in plugins or "iat-html" in plugins do
        """
        @media (max-width: 768px) {
          #trial_left_align {
            top: 8em !important;
            left: 8px !important;
            font-size: clamp(0.6rem, 2vw, 0.8rem) !important;
            max-width: 40% !important;
            line-height: 1.3 !important;
          }
          #trial_right_align {
            top: 8em !important;
            right: 8px !important;
            font-size: clamp(0.6rem, 2vw, 0.8rem) !important;
            max-width: 40% !important;
            text-align: right !important;
            line-height: 1.3 !important;
          }
        }
        #jspsych-iat-stim {
          display: flex !important;
          justify-content: center !important;
          align-items: center !important;
          min-height: 50vh !important;
        }
        #jspsych-iat-stim img {
          max-height: 50vh !important;
          max-width: 90% !important;
          width: auto !important;
          height: auto !important;
          transform: translateY(-25%) !important;
        }
        """
      else
        ""
      end

    tsb_css <> iat_css
  end

  def required_scripts(study) do
    custom_names = Registry.custom_plugin_names()

    plugins =
      study.trials
      |> collect_plugins()
      |> Enum.uniq()
      |> Enum.map(fn name ->
        if name in custom_names,
          do: "#{@custom_base}/#{name}.js",
          else: "#{@jspsych_base}/#{name}.js"
      end)

    extension_scripts =
      if collect_tsb_layouts(study.trials) != [],
        do: ["#{@jspsych_base}/extension-touchscreen-buttons.js"],
        else: []

    ["#{@jspsych_base}/jspsych.js"] ++ extension_scripts ++ plugins
  end

  def generate_inline_js(study) do
    tsb_layouts = collect_tsb_layouts(study.trials)
    {_, declarations, root_var_names} = emit_nodes(study.trials, 1)

    all_js = Enum.join(declarations, "\n\n")
    root_vars = Enum.join(root_var_names, ", ")

    extensions_js =
      case tsb_layouts do
        [] ->
          ""

        layouts ->
          layouts_js =
            Enum.map_join(layouts, ", ", fn {name, buttons} ->
              buttons_js = Enum.map_join(buttons, ", ", &btn_to_js/1)
              ~s(#{name}: [#{buttons_js}])
            end)

          "extensions: [{ type: jsPsychExtensionTouchscreenButtons, params: { #{layouts_js} } }],\n      "
      end

    """
    const __preview__ = new URLSearchParams(window.location.search).has('preview');

    function saveData(trialData) {
      if (__preview__) {
        document.body.innerHTML = [
          "<div style='display:flex;flex-direction:column;align-items:center;justify-content:center;",
          "height:100vh;font-family:sans-serif;gap:1rem;padding:2rem;text-align:center'>",
          "<p style='font-size:1.2rem'>✓ Preview complete</p>",
          "<button onclick='location.reload()' ",
          "style='padding:8px 20px;border:1px solid #ccc;border-radius:6px;cursor:pointer;background:#fff'>",
          "↺ Restart preview</button></div>"
        ].join('');
        return;
      }
      const csrfToken = document.querySelector('meta[name="csrf-token"]').content;
      fetch(window.location.pathname + "/user-data", {
        method: "POST",
        headers: { "content-type": "application/json", "x-csrf-token": csrfToken },
        body: JSON.stringify({ data: trialData })
      })
        .then(r => r.json())
        .then(result => {
          if (result.status === "already_submitted") {
            document.body.innerHTML = "<div style='display:flex;align-items:center;justify-content:center;height:100vh;font-family:sans-serif'><p>You have already completed this study. Thank you!</p></div>";
          }
        })
        .catch(err => console.error("Failed to save data:", err));
    }

    const jsPsych = initJsPsych({
      #{extensions_js}on_finish: function() { saveData(jsPsych.data.get().values()); }
    });

    #{all_js}

    jsPsych.run([#{root_vars}]);
    """
  end

  def plugin_to_js_var(plugin_name) do
    parts = String.split(plugin_name, "-")
    "jsPsych" <> Enum.map_join(parts, &String.capitalize/1)
  end

  defp default_tsb_buttons do
    [
      %{"key" => "e", "preset" => "left", "label" => "←", "color" => ""},
      %{"key" => "i", "preset" => "right", "label" => "→", "color" => ""}
    ]
  end

  # Collects unique touchscreen-button layouts across all trials.
  # Returns [{layout_name, buttons}] deduplicated by name.
  defp collect_tsb_layouts(nodes) do
    nodes
    |> Enum.flat_map(fn node ->
      child_layouts = collect_tsb_layouts(node.children || [])
      tsb = get_in(node.extensions || %{}, ["touchscreen-buttons"])

      if tsb && tsb["enabled"] do
        buttons = tsb["buttons"] || default_tsb_buttons()
        name = tsb_layout_name(buttons)
        [{name, buttons} | child_layouts]
      else
        child_layouts
      end
    end)
    |> Enum.uniq_by(fn {name, _} -> name end)
  end

  defp tsb_layout_name(buttons) do
    keys = Enum.map_join(buttons, "_", & &1["key"])
    "tsb_#{keys}"
  end

  # Custom presets not in the extension library — rendered via CSS class + inline style overrides.
  # The extension sets inline left/bottom/width/height when no recognized preset is matched (l===null),
  # so we must emit a style object to override those inline values with the correct dimensions.
  @custom_tsb_presets %{
    "fill_bottom"  => {"jsTouchButtonFillBottom", "left:'0',bottom:'0',top:'unset',right:'unset',width:'100%',height:'20%'"},
    "left_middle"  => {"jsTouchButtonLeftMiddle",  "left:'0',top:'30%',bottom:'unset',right:'unset',width:'30%',height:'40%'"},
    "right_middle" => {"jsTouchButtonRightMiddle", "right:'0',top:'30%',bottom:'unset',left:'unset',width:'30%',height:'40%'"}
  }

  defp btn_to_js(btn) do
    preset = btn["preset"] || "left"
    color = btn["color"] || ""
    color_js = if color != "", do: ~s(, color: '#{color}'), else: ""
    label = btn["label"] || ""
    label_js = if label != "", do: ~s(, innerText: '#{label}'), else: ""

    case Map.get(@custom_tsb_presets, preset) do
      nil ->
        ~s({ key: '#{btn["key"]}', preset: '#{preset}'#{label_js}#{color_js} })

      {css_class, style_js} ->
        ~s({ key: '#{btn["key"]}', css: '#{css_class}', style: {#{style_js}}#{label_js}#{color_js} })
    end
  end

  defp collect_plugins(nodes) do
    Enum.flat_map(nodes, fn node ->
      child_plugins = collect_plugins(node.children || [])
      if node.plugin, do: [node.plugin | child_plugins], else: child_plugins
    end)
  end

  defp emit_nodes(nodes, counter) do
    Enum.reduce(nodes, {counter, [], []}, fn node, {cnt, all_decls, all_var_names} ->
      {new_cnt, node_decls, var_name} = emit_node(node, cnt)
      {new_cnt, all_decls ++ node_decls, all_var_names ++ [var_name]}
    end)
  end

  defp emit_node(%{node_type: "counterbalanced_group"} = node, counter) do
    var_name = "timeline#{counter}"
    children = node.children || []
    split = get_in(node.config || %{}, ["split"]) || div(length(children), 2)
    {version_a_children, version_b_children} = Enum.split(children, split)

    {counter_a, version_a_decls, version_a_vars} = emit_nodes(version_a_children, counter + 1)
    {counter_b, version_b_decls, version_b_vars} = emit_nodes(version_b_children, counter_a)

    version_a_js = Enum.join(version_a_vars, ", ")
    version_b_js = Enum.join(version_b_vars, ", ")

    own_decl = """
    const #{var_name} = (function() {
      const versionA = [#{version_a_js}];
      const versionB = [#{version_b_js}];
      return Math.random() < 0.5 ? { timeline: versionA } : { timeline: versionB };
    })();\
    """

    {counter_b, version_a_decls ++ version_b_decls ++ [own_decl], var_name}
  end

  defp emit_node(%{node_type: "template_group"} = node, counter) do
    var_name = "timeline#{counter}"
    {new_counter, child_decls, child_var_names} = emit_nodes(node.children || [], counter + 1)
    children_js = Enum.join(child_var_names, ", ")
    own_decl = "const #{var_name} = {\n  timeline: [#{children_js}]\n};"
    {new_counter, child_decls ++ [own_decl], var_name}
  end

  defp emit_node(%{node_type: "timeline"} = node, counter) do
    var_name = "timeline#{counter}"
    {new_counter, child_decls, child_var_names} = emit_nodes(node.children || [], counter + 1)
    children_js = Enum.join(child_var_names, ", ")
    extra_js = timeline_config_to_js(node.config || %{})
    own_decl = "const #{var_name} = {\n  timeline: [#{children_js}],#{extra_js}\n};"
    {new_counter, child_decls ++ [own_decl], var_name}
  end

  defp emit_node(node, counter) do
    var_name = "trial#{counter}"
    data_tag = node.config["data_tag"]
    clean_config = Map.delete(node.config, "data_tag")
    config_js = config_to_js(clean_config, node.plugin)

    data_tag_js =
      if data_tag && data_tag != "" do
        escaped = String.replace(data_tag, "`", "\\`")
        "  data: { tag: `#{escaped}` },\n"
      else
        ""
      end

    extensions_js =
      case get_in(node.extensions || %{}, ["touchscreen-buttons"]) do
        %{"enabled" => true} = tsb ->
          buttons = tsb["buttons"] || default_tsb_buttons()
          layout = tsb_layout_name(buttons)
          "  extensions: [{ type: jsPsychExtensionTouchscreenButtons, params: { layout: '#{layout}' } }],\n"

        _ ->
          ""
      end

    decl = "const #{var_name} = {\n  type: #{plugin_to_js_var(node.plugin)},\n#{extensions_js}#{data_tag_js}#{config_js}};"
    {counter + 1, [decl], var_name}
  end

  defp timeline_config_to_js(config) do
    [
      if(config["timeline_variables"] not in [nil, []],
        do: "\n  timeline_variables: #{value_to_js(config["timeline_variables"])},",
        else: nil
      ),
      if(config["repetitions"] && config["repetitions"] != 1,
        do: "\n  repetitions: #{config["repetitions"]},",
        else: nil
      ),
      if(config["randomize_order"],
        do: "\n  randomize_order: true,",
        else: nil
      ),
      if(config["data"] not in [nil, %{}],
        do: "\n  data: #{value_to_js(config["data"])},",
        else: nil
      ),
      if(config["conditional_function"] not in [nil, ""],
        do: "\n  conditional_function: function() {\n#{indent_js_body(config["conditional_function"])}\n  },",
        else: nil
      ),
      if(config["loop_function"] not in [nil, ""],
        do: "\n  loop_function: function(data) {\n#{indent_js_body(config["loop_function"])}\n  },",
        else: nil
      )
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("")
  end

  defp indent_js_body(body) do
    body
    |> String.trim()
    |> String.split("\n")
    |> Enum.map_join("\n", &("    " <> &1))
  end

  defp config_to_js(config, _plugin) when map_size(config) == 0, do: ""

  defp config_to_js(config, "survey") do
    params_js =
      config
      |> Enum.map(fn {key, val} -> "  #{key}: #{value_to_js(val)}," end)
      |> Enum.join("\n")

    survey_fn = """
      survey_function: function(survey) {
        survey.onTextMarkdown.add(function(s, opts) { opts.html = opts.text; });
      },
    """

    params_js <> "\n" <> survey_fn
  end

  defp config_to_js(config, _plugin) do
    {fn_entries, normal_entries} = Map.split(config, ["stimulus_function"])

    normal_js =
      normal_entries
      |> Enum.map(fn {key, val} -> "  #{key}: #{value_to_js(val)}," end)
      |> Enum.join("\n")

    fn_js =
      fn_entries
      |> Enum.map(fn {_key, body} ->
        "  stimulus: function() {\n#{indent_js_body(body)}\n  },"
      end)
      |> Enum.join("\n")

    [normal_js, fn_js]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
    |> then(&(&1 <> "\n"))
  end

  # Converts {{varName}} tokens to jsPsych.timelineVariable('varName') calls
  defp value_to_js(val) when is_binary(val) do
    case Regex.run(~r/^\{\{(\w+)\}\}$/, val) do
      [_, var_name] -> "jsPsych.timelineVariable('#{var_name}')"
      _ ->
        escaped = String.replace(val, "`", "\\`")
        "`#{escaped}`"
    end
  end

  defp value_to_js(val) when is_integer(val), do: Integer.to_string(val)
  defp value_to_js(val) when is_float(val), do: Float.to_string(val)
  defp value_to_js(true), do: "true"
  defp value_to_js(false), do: "false"
  defp value_to_js(nil), do: "null"

  defp value_to_js(val) when is_list(val) do
    items = Enum.map_join(val, ", ", &value_to_js/1)
    "[#{items}]"
  end

  defp value_to_js(val) when is_map(val) do
    pairs =
      val
      |> Enum.map(fn {k, v} -> "#{k}: #{value_to_js(v)}" end)
      |> Enum.join(", ")

    "{#{pairs}}"
  end
end
