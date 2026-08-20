defmodule Socho.Studies.JsGenerator do
  @moduledoc """
  Generates jsPsych HTML page assets from a Study with preloaded trials.

  Given a study whose `trials` field has been populated as a nested tree, this
  module produces three assets that are embedded into the experiment HTML page:

  - `required_stylesheets/1` — CSS `<link>` paths
  - `required_scripts/1` — JS `<script src>` paths
  - `generate_inline_js/1` — the inline `<script>` block that initialises and
    runs the jsPsych experiment

  ## The trial tree

  Trials are stored flat in the database but assembled into a tree via the
  `children` virtual field before being passed here. Each node has a
  `node_type` that controls how it is emitted:

  | `node_type`             | Description |
  |-------------------------|-------------|
  | `"trial"`               | Leaf node — one jsPsych plugin call |
  | `"timeline"`            | Container — supports `repetitions`, `randomize_order`, `timeline_variables`, conditional/loop functions |
  | `"template_group"`      | Plain container — no extra config; used by study builder templates |
  | `"counterbalanced_group"` | Randomly picks one group of children at runtime to counterbalance trial order across participants |

  ## JS variable naming

  The emitter walks the tree depth-first, assigning sequential names. Leaf
  trials become `trial{n}`; any container becomes `timeline{n}`. The counter
  threads through every recursive call so names are globally unique within the
  page.

  Plugin names map to jsPsych constructor variables by capitalising each
  hyphen-separated segment:

      "html-keyboard-response"  →  jsPsychHtmlKeyboardResponse
      "survey"                  →  jsPsychSurvey

  The `"pairwise-compare"` plugin is special: it is a synthetic type that
  expands into a `jsPsychMultiImageSelect` IIFE at emit time.

  ## Example

      study = %{
        trials: [
          %Trial{
            node_type: "timeline",
            plugin: nil,
            config: %{"repetitions" => 2},
            extensions: %{},
            children: [
              %Trial{
                node_type: "trial",
                plugin: "image-keyboard-response",
                config: %{"stimulus" => "cat.jpg", "choices" => ["f", "j"]},
                extensions: %{},
                children: []
              },
              %Trial{
                node_type: "trial",
                plugin: "html-keyboard-response",
                config: %{"stimulus" => "<p>Done</p>"},
                extensions: %{},
                children: []
              }
            ]
          }
        ]
      }

      JsGenerator.required_stylesheets(study)
      #=> ["/vendor/jspsych/jspsych.css"]

      JsGenerator.required_scripts(study)
      #=> ["/vendor/jspsych/jspsych.js",
      #    "/vendor/jspsych/image-keyboard-response.js",
      #    "/vendor/jspsych/html-keyboard-response.js"]

      JsGenerator.generate_inline_js(study)
      # (boilerplate omitted)
      #=> ...
      #   const trial2 = {
      #     type: jsPsychImageKeyboardResponse,
      #     stimulus: `cat.jpg`,
      #     choices: [`f`, `j`],
      #   };
      #   const trial3 = {
      #     type: jsPsychHtmlKeyboardResponse,
      #     stimulus: `<p>Done</p>`,
      #   };
      #   const timeline1 = {
      #     timeline: [trial2, trial3],
      #     repetitions: 2,
      #   };
      #   jsPsych.run([timeline1]);

  See `docs/dev-guides/05-js-generator.md` for full worked examples of every
  node type.
  """

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

  @doc """
  Generates the JS code (a valid JSPsych experiment) that is sent to the Participant
  """
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

  @doc """
  Collect names of jspsych plugins used in the Trial Tree
  """
  def collect_plugins(nodes) do
    Enum.flat_map(nodes, fn node ->
      child_plugins = collect_plugins(node.children || [])
      own =
        case node.plugin do
          "pairwise-compare" -> ["multi-image-select"]
          p when not is_nil(p) -> [p]
          _ -> []
        end
      own ++ child_plugins
    end)
  end

  def emit_nodes(nodes, counter) do
    Enum.reduce(nodes, {counter, [], []}, fn node, {cnt, all_decls, all_var_names} ->
      {new_cnt, node_decls, var_name} = emit_node(node, cnt)
      {new_cnt, all_decls ++ node_decls, all_var_names ++ [var_name]}
    end)
  end

  def emit_node(%{node_type: "counterbalanced_group"} = node, counter) do
    var_name = "timeline#{counter}"
    children = node.children || []
    config = node.config || %{}

    groups =
      case get_in(config, ["group_sizes"]) do
        sizes when is_list(sizes) ->
          {groups, _} =
            Enum.map_reduce(sizes, children, fn size, remaining ->
              Enum.split(remaining, size)
            end)
          groups

        _ ->
          split = get_in(config, ["split"]) || div(length(children), 2)
          {a, b} = Enum.split(children, split)
          [a, b]
      end

    {final_counter, all_decls, group_var_lists} =
      Enum.reduce(groups, {counter + 1, [], []}, fn group_children, {cnt, decls, var_lists} ->
        {new_cnt, group_decls, group_vars} = emit_nodes(group_children, cnt)
        {new_cnt, decls ++ group_decls, var_lists ++ [group_vars]}
      end)

    versions_js =
      group_var_lists
      |> Enum.map(fn vars -> "[#{Enum.join(vars, ", ")}]" end)
      |> Enum.join(",\n      ")

    own_decl = """
    const #{var_name} = (function() {
      const versions = [
        #{versions_js}
      ];
      return { timeline: versions[Math.floor(Math.random() * versions.length)] };
    })();\
    """

    {final_counter, all_decls ++ [own_decl], var_name}
  end

  def emit_node(%{node_type: "template_group"} = node, counter) do
    var_name = "timeline#{counter}"
    {new_counter, child_decls, child_var_names} = emit_nodes(node.children || [], counter + 1)
    children_js = Enum.join(child_var_names, ", ")
    own_decl = "const #{var_name} = {\n  timeline: [#{children_js}]\n};"
    {new_counter, child_decls ++ [own_decl], var_name}
  end

  def emit_node(%{node_type: "timeline"} = node, counter) do
    var_name = "timeline#{counter}"
    {new_counter, child_decls, child_var_names} = emit_nodes(node.children || [], counter + 1)
    children_js = Enum.join(child_var_names, ", ")
    extra_js = timeline_config_to_js(node.config || %{})
    own_decl = "const #{var_name} = {\n  timeline: [#{children_js}],#{extra_js}\n};"
    {new_counter, child_decls ++ [own_decl], var_name}
  end

  def emit_node(%{plugin: "pairwise-compare"} = node, counter) do
    var_name = "timeline#{counter}"
    config = node.config || %{}
    pairs = config["pairs"] || []
    image_width = config["image_width"] || 300
    image_height = config["image_height"] || 300
    prompt = config["prompt"]
    data_tag = config["data_tag"]

    pairs_js = Jason.encode!(pairs)

    prompt_js =
      if prompt && prompt != "",
        do: "`#{String.replace(prompt, "`", "\\`")}`",
        else: "null"

    data_js =
      if data_tag && data_tag != "" do
        escaped = String.replace(data_tag, "`", "\\`")
        "        data: { data_tag: `#{escaped}` },\n"
      else
        ""
      end

    own_decl = """
    const #{var_name} = (function() {
      var _pairs = #{pairs_js};
      var _shuffled = jsPsych.randomization.shuffle(_pairs.slice());
      var _timeline_vars = _shuffled.map(function(pair) { return { _pw_images: pair }; });
      return {
        timeline: [{
          type: jsPsychMultiImageSelect,
          images: jsPsych.timelineVariable('_pw_images'),
          columns: 2,
          image_width: #{image_width},
          image_height: #{image_height},
          prompt: #{prompt_js},
    #{data_js}    }],
        timeline_variables: _timeline_vars,
      };
    })();\
    """

    {counter + 1, [own_decl], var_name}
  end

  def emit_node(node, counter) do
    var_name = "trial#{counter}"
    data_tag = node.config["data_tag"]
    clean_config = Map.delete(node.config, "data_tag")
    config_js = config_to_js(clean_config, node.plugin)

    data_tag_js =
      if data_tag && data_tag != "" do
        escaped = String.replace(data_tag, "`", "\\`")
        "  data: { data_tag: `#{escaped}` },\n"
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
      (case skip_unless_to_js(config["skip_unless"]) do
        nil ->
          if config["conditional_function"] not in [nil, ""],
            do: "\n  conditional_function: function() {\n#{indent_js_body(config["conditional_function"])}\n  },",
            else: nil
        body ->
          "\n  conditional_function: function() {\n#{indent_js_body(body)}\n  },"
      end),
      if(config["loop_function"] not in [nil, ""],
        do: "\n  loop_function: function(data) {\n#{indent_js_body(config["loop_function"])}\n  },",
        else: nil
      )
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("")
  end

  defp skip_unless_to_js(%{"mode" => "gui", "conditions" => [_ | _] = conditions} = su) do
    join = if su["join"] == "OR", do: " || ", else: " && "

    indexed = Enum.with_index(conditions)

    fetches =
      Enum.map_join(indexed, "\n", fn {cond, i} ->
        tag = Jason.encode!(cond["tag"] || "")
        "const _su#{i} = jsPsych.data.get().filter({data_tag: #{tag}}).last(1).values()[0];"
      end)

    exprs =
      Enum.map(indexed, fn {cond, i} ->
        var = "_su#{i}"
        field = cond["field"] || "response"
        question = cond["question"]
        op = cond["op"] || "eq"
        val = cond["value"] || ""
        negate = cond["negate"] == true

        # When a specific survey question is selected, access response.questionName
        access =
          if field == "response" && question && question != "" do
            "#{var}.response && #{var}.response[#{Jason.encode!(question)}]"
          else
            "#{var}.#{field}"
          end

        inner =
          case op do
            "eq" -> "#{var} && #{access} === #{Jason.encode!(val)}"
            "neq" -> "#{var} && #{access} !== #{Jason.encode!(val)}"
            "contains" -> "#{var} && String(#{access}).includes(#{Jason.encode!(val)})"
            "is_true" -> "#{var} && #{access} === true"
            "is_false" -> "#{var} && #{access} === false"
            "lt" -> "#{var} && #{access} < #{val}"
            "gt" -> "#{var} && #{access} > #{val}"
            _ -> "false"
          end

        if negate, do: "!(#{inner})", else: inner
      end)

    "#{fetches}\nreturn #{Enum.join(exprs, join)};"
  end

  defp skip_unless_to_js(_), do: nil

  defp indent_js_body(body) do
    body
    |> String.trim()
    |> String.split("\n")
    |> Enum.map_join("\n", &("    " <> &1))
  end

  defp config_to_js(config, _plugin) when map_size(config) == 0, do: ""

  defp config_to_js(config, "survey") do
    survey_json = config["survey_json"] || %{}
    elements = survey_json["elements"] || []

    {dynamic_elements, _} =
      Enum.split_with(elements, fn el ->
        is_binary(el["dyn_source_tag"]) and el["dyn_source_tag"] != ""
      end)

    clean_elements =
      Enum.map(elements, fn el ->
        Map.drop(el, ["dyn_source_tag", "dyn_source_question", "dyn_source_columns", "static_columns"])
      end)

    clean_config = Map.put(config, "survey_json", Map.put(survey_json, "elements", clean_elements))

    params_js =
      clean_config
      |> Enum.map(fn {key, val} -> "  #{key}: #{value_to_js(val)}," end)
      |> Enum.join("\n")

    survey_fn = """
      survey_function: function(survey) {
        survey.onTextMarkdown.add(function(s, opts) { opts.html = opts.text; });
      },
    """

    on_start_js =
      if dynamic_elements != [] do
        patches =
          Enum.map_join(dynamic_elements, "\n", fn el ->
            tag = Jason.encode!(el["dyn_source_tag"])
            question = Jason.encode!(el["dyn_source_question"] || "")
            scale = Jason.encode!(el["dyn_source_columns"] || [])
            q_name = Jason.encode!(el["name"] || "")

            "    (function() {\n" <>
            "      var _src = jsPsych.data.get().filter({data_tag: #{tag}}).last(1).values()[0];\n" <>
            "      var _resp = _src && _src.response && _src.response[#{question}];\n" <>
            "      var _scale = #{scale};\n" <>
            "      var _dyn = [];\n" <>
            "      if (_resp) {\n" <>
            "        if (_scale.length > 0) {\n" <>
            "          for (var _i = 0; _i < _scale.length && _dyn.length < 4; _i++) {\n" <>
            "            var _col = _scale[_i];\n" <>
            "            var _cands = [];\n" <>
            "            Object.keys(_resp).forEach(function(row) {\n" <>
            "              var v = _resp[row];\n" <>
            "              if (v === _col || (Array.isArray(v) && v.indexOf(_col) > -1) || (v && typeof v === 'object' && !Array.isArray(v) && v[_col] === true)) _cands.push(row);\n" <>
            "            });\n" <>
            "            for (var _ci = _cands.length - 1; _ci > 0; _ci--) { var _ck = Math.floor(Math.random() * (_ci + 1)); var _ct = _cands[_ci]; _cands[_ci] = _cands[_ck]; _cands[_ck] = _ct; }\n" <>
            "            _dyn = _dyn.concat(_cands.slice(0, 4 - _dyn.length));\n" <>
            "          }\n" <>
            "        } else {\n" <>
            "          var _keys = Object.keys(_resp);\n" <>
            "          for (var _fi = 0; _fi < _keys.length && _dyn.length < 4; _fi++) _dyn.push(_keys[_fi]);\n" <>
            "        }\n" <>
            "        for (var _j = _dyn.length - 1; _j > 0; _j--) {\n" <>
            "          var _k = Math.floor(Math.random() * (_j + 1));\n" <>
            "          var _t = _dyn[_j]; _dyn[_j] = _dyn[_k]; _dyn[_k] = _t;\n" <>
            "        }\n" <>
            "      }\n" <>
            "      var _static = #{Jason.encode!(el["static_columns"] || [])};\n" <>
            "      var _el = trial.survey_json.elements.find(function(e) { return e.name === #{q_name}; });\n" <>
            (cond do
              el["type"] == "matrixdropdown" and el["inputType"] == "number" ->
                min_js = if el["min"] != nil, do: ", min: #{el["min"]}", else: ""
                max_js = if el["max"] != nil, do: ", max: #{el["max"]}", else: ""
                "      if (_el) _el.columns = _static.map(function(n){return{name:n,title:n,cellType:\"text\",inputType:\"number\"#{min_js}#{max_js}};}).concat(_dyn.map(function(n){return{name:n,title:n,cellType:\"text\",inputType:\"number\"#{min_js}#{max_js}};}));\n"
              el["type"] == "matrixdropdown" ->
                "      if (_el) _el.columns = _static.map(function(n){return{name:n,title:n};}).concat(_dyn.map(function(n){return{name:n,title:n};}));\n"
              true ->
                "      if (_el) _el.columns = _static.concat(_dyn);\n"
            end) <>
            "    })();"
          end)

        "  on_start: function(trial) {\n#{patches}\n  },\n"
      else
        ""
      end

    params_js <> "\n" <> survey_fn <> on_start_js
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
