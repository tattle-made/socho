defmodule Socho.Studies.JsGenerator do
  @moduledoc "Generates jsPsych HTML page assets from a Study with preloaded trials."

  @jspsych_base "/vendor/jspsych"

  def required_stylesheets(_study) do
    ["#{@jspsych_base}/jspsych.css"]
  end

  def required_scripts(study) do
    plugins =
      study.trials
      |> collect_plugins()
      |> Enum.uniq()
      |> Enum.map(&"#{@jspsych_base}/#{&1}.js")

    ["#{@jspsych_base}/jspsych.js" | plugins]
  end

  def generate_inline_js(study) do
    {_, declarations, root_var_names} = emit_nodes(study.trials, 1)

    all_js = Enum.join(declarations, "\n\n")
    root_vars = Enum.join(root_var_names, ", ")

    """
    function saveData(csvData) {
      const csrfToken = document.querySelector('meta[name="csrf-token"]').content;
      fetch(window.location.pathname + "/user-data", {
        method: "POST",
        headers: { "content-type": "application/json", "x-csrf-token": csrfToken },
        body: JSON.stringify({ data: csvData })
      })
        .then(r => r.json())
        .then(result => console.log("Data saved:", result))
        .catch(err => console.error("Failed to save data:", err));
    }

    const jsPsych = initJsPsych({
      on_finish: function() { saveData(jsPsych.data.get().csv()); }
    });

    #{all_js}

    jsPsych.run([#{root_vars}]);
    """
  end

  def plugin_to_js_var(plugin_name) do
    parts = String.split(plugin_name, "-")
    "jsPsych" <> Enum.map_join(parts, &String.capitalize/1)
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
    config_js = config_to_js(node.config, node.plugin)
    decl = "const #{var_name} = {\n  type: #{plugin_to_js_var(node.plugin)},\n#{config_js}};"
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
      )
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("")
  end

  defp config_to_js(config, _plugin) when map_size(config) == 0, do: ""

  defp config_to_js(config, _plugin) do
    config
    |> Enum.map(fn {key, val} -> "  #{key}: #{value_to_js(val)}," end)
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
