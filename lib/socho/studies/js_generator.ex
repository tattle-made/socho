defmodule Socho.Studies.JsGenerator do
  @moduledoc "Generates jsPsych HTML page assets from a Study with preloaded trials."

  @jspsych_base "/vendor/jspsych"

  def required_stylesheets(_study) do
    ["#{@jspsych_base}/jspsych.css"]
  end

  def required_scripts(study) do
    plugins =
      study.trials
      |> Enum.map(& &1.plugin)
      |> Enum.uniq()
      |> Enum.map(&"#{@jspsych_base}/#{&1}.js")

    ["#{@jspsych_base}/jspsych.js" | plugins]
  end

  def generate_inline_js(study) do
    timeline_items =
      study.trials
      |> Enum.with_index(1)
      |> Enum.map(fn {trial, idx} ->
        var_name = "trial#{idx}"
        config_js = config_to_js(trial.config, trial.plugin)
        "const #{var_name} = {\n  type: #{plugin_to_js_var(trial.plugin)},\n#{config_js}};"
      end)
      |> Enum.join("\n\n")

    timeline_vars =
      study.trials
      |> Enum.with_index(1)
      |> Enum.map(fn {_, idx} -> "trial#{idx}" end)
      |> Enum.join(", ")

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

    #{timeline_items}

    jsPsych.run([#{timeline_vars}]);
    """
  end

  # Converts a plugin name like "html-keyboard-response" to "jsPsychHtmlKeyboardResponse"
  def plugin_to_js_var(plugin_name) do
    parts = String.split(plugin_name, "-")
    "jsPsych" <> Enum.map_join(parts, &String.capitalize/1)
  end

  defp config_to_js(config, _plugin) when map_size(config) == 0, do: ""

  defp config_to_js(config, _plugin) do
    config
    |> Enum.map(fn {key, val} -> "  #{key}: #{value_to_js(val)}," end)
    |> Enum.join("\n")
    |> then(&(&1 <> "\n"))
  end

  defp value_to_js(val) when is_binary(val) do
    escaped = String.replace(val, "`", "\\`")
    "`#{escaped}`"
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
