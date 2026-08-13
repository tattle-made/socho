defmodule SochoWeb.StudyLive.DataTags do
  @moduledoc false

  @doc """
  Walks the trial node tree and collects every node that has a non-empty
  `data_tag`. Returns a sorted, deduplicated list of maps:

      %{
        "tag"       => "screening",
        "plugin"    => "survey",
        "questions" => [
          %{"name" => "age", "title" => "Your age?", "type" => "radiogroup",
            "choices" => ["<15", "16-40", ">40"]}
        ]
      }

  Questions are only populated for survey blocks; html-type elements are
  excluded. Choice values are normalised to plain strings.
  """
  def collect(nodes) do
    nodes
    |> Enum.flat_map(&collect_node/1)
    |> Enum.uniq_by(fn dt -> dt["tag"] end)
    |> Enum.sort_by(fn dt -> dt["tag"] end)
  end

  defp collect_node(node) do
    child_tags = collect(node[:children] || node.children || [])
    tag = get_in(node[:config] || node.config || %{}, ["data_tag"])

    if tag && tag != "" do
      [%{"tag" => tag, "plugin" => node[:plugin] || node.plugin || "", "questions" => questions(node)} | child_tags]
    else
      child_tags
    end
  end

  defp questions(node) do
    plugin = node[:plugin] || node.plugin

    if plugin == "survey" do
      config = node[:config] || node.config || %{}
      elements = get_in(config, ["survey_json", "elements"]) || []

      elements
      |> Enum.reject(fn el -> el["type"] == "html" end)
      |> Enum.map(fn el ->
        plain_title = el["title"] |> strip_html() |> then(fn t -> if t == "", do: el["name"] || "", else: t end)
        %{
          "name" => el["name"] || "",
          "title" => plain_title,
          "type" => el["type"] || "text",
          "inputType" => el["inputType"],
          "choices" => normalise_choices(el["choices"] || [])
        }
      end)
    else
      []
    end
  end

  defp strip_html(nil), do: ""
  defp strip_html(html), do: html |> String.replace(~r/<[^>]+>/, "") |> String.trim()

  defp normalise_choices(choices) do
    Enum.map(choices, fn
      c when is_binary(c) -> c
      %{"value" => v} -> to_string(v)
      %{"text" => t} -> to_string(t)
      other -> to_string(other)
    end)
  end
end
