defmodule SochoWeb.StudyLive.DataTagsTest do
  use ExUnit.Case, async: true

  alias SochoWeb.StudyLive.DataTags

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp node(plugin, tag, extra_config \\ %{}, children \\ []) do
    %{
      plugin: plugin,
      config: Map.merge(%{"data_tag" => tag}, extra_config),
      children: children
    }
  end

  defp survey_node(tag, questions, children \\ []) do
    node("survey", tag, %{"survey_json" => %{"elements" => questions}}, children)
  end

  defp question(name, type, opts \\ []) do
    base = %{"name" => name, "type" => type}
    base = if Keyword.has_key?(opts, :title), do: Map.put(base, "title", opts[:title]), else: base
    base = if Keyword.has_key?(opts, :choices), do: Map.put(base, "choices", opts[:choices]), else: base
    base
  end

  # ---------------------------------------------------------------------------
  # Basic collection
  # ---------------------------------------------------------------------------

  describe "collect/1" do
    test "returns empty list for empty input" do
      assert DataTags.collect([]) == []
    end

    test "ignores nodes without a data_tag" do
      nodes = [node("html-button-response", ""), node("html-button-response", nil)]
      assert DataTags.collect(nodes) == []
    end

    test "includes non-survey nodes with a data_tag" do
      nodes = [node("html-button-response", "consent")]
      assert DataTags.collect(nodes) == [
        %{"tag" => "consent", "plugin" => "html-button-response", "questions" => []}
      ]
    end

    test "results are sorted alphabetically by tag" do
      nodes = [
        node("html-button-response", "zebra"),
        node("html-button-response", "apple"),
        node("html-button-response", "mango")
      ]

      tags = DataTags.collect(nodes) |> Enum.map(& &1["tag"])
      assert tags == ["apple", "mango", "zebra"]
    end

    test "deduplicates by tag, keeping the first occurrence" do
      nodes = [
        node("html-button-response", "shared-tag"),
        node("survey", "shared-tag")
      ]

      result = DataTags.collect(nodes)
      assert length(result) == 1
      assert hd(result)["plugin"] == "html-button-response"
    end
  end

  # ---------------------------------------------------------------------------
  # Survey question extraction
  # ---------------------------------------------------------------------------

  describe "survey block questions" do
    test "extracts questions with name, title, type, and choices" do
      nodes = [
        survey_node("screener", [
          question("age", "radiogroup", title: "Your age?", choices: ["<15", "16-40", ">40"])
        ])
      ]

      [entry] = DataTags.collect(nodes)
      assert entry["tag"] == "screener"
      assert entry["plugin"] == "survey"

      [q] = entry["questions"]
      assert q["name"] == "age"
      assert q["title"] == "Your age?"
      assert q["type"] == "radiogroup"
      assert q["choices"] == ["<15", "16-40", ">40"]
    end

    test "falls back to name when title is absent" do
      nodes = [survey_node("s", [question("mood", "radiogroup")])]

      [entry] = DataTags.collect(nodes)
      [q] = entry["questions"]
      assert q["title"] == "mood"
    end

    test "includes questions with no choices (open-ended types)" do
      nodes = [
        survey_node("s", [
          question("comments", "comment"),
          question("age_exact", "number")
        ])
      ]

      [entry] = DataTags.collect(nodes)
      assert length(entry["questions"]) == 2
      assert Enum.all?(entry["questions"], fn q -> q["choices"] == [] end)
    end

    test "filters out html-type elements" do
      nodes = [
        survey_node("s", [
          question("intro", "html"),
          question("q1", "radiogroup", choices: ["Yes", "No"])
        ])
      ]

      [entry] = DataTags.collect(nodes)
      assert length(entry["questions"]) == 1
      assert hd(entry["questions"])["name"] == "q1"
    end

    test "returns empty questions list for survey with no elements" do
      nodes = [survey_node("empty-survey", [])]

      [entry] = DataTags.collect(nodes)
      assert entry["questions"] == []
    end

    test "returns empty questions list for survey with missing survey_json" do
      nodes = [node("survey", "bare-survey")]

      [entry] = DataTags.collect(nodes)
      assert entry["questions"] == []
    end
  end

  # ---------------------------------------------------------------------------
  # Choice normalisation
  # ---------------------------------------------------------------------------

  describe "choice normalisation" do
    test "plain string choices are passed through" do
      nodes = [survey_node("s", [question("q", "radiogroup", choices: ["a", "b"])])]

      [entry] = DataTags.collect(nodes)
      assert hd(entry["questions"])["choices"] == ["a", "b"]
    end

    test "map choices with 'value' key are extracted" do
      choices = [%{"value" => "opt1", "text" => "Option 1"}, %{"value" => "opt2", "text" => "Option 2"}]
      nodes = [survey_node("s", [question("q", "dropdown", choices: choices)])]

      [entry] = DataTags.collect(nodes)
      assert hd(entry["questions"])["choices"] == ["opt1", "opt2"]
    end

    test "map choices with only 'text' key fall back to text" do
      choices = [%{"text" => "Label A"}, %{"text" => "Label B"}]
      nodes = [survey_node("s", [question("q", "radiogroup", choices: choices)])]

      [entry] = DataTags.collect(nodes)
      assert hd(entry["questions"])["choices"] == ["Label A", "Label B"]
    end

    test "mixed string and map choices are normalised together" do
      choices = ["plain", %{"value" => "from_map"}]
      nodes = [survey_node("s", [question("q", "radiogroup", choices: choices)])]

      [entry] = DataTags.collect(nodes)
      assert hd(entry["questions"])["choices"] == ["plain", "from_map"]
    end
  end

  # ---------------------------------------------------------------------------
  # Tree traversal
  # ---------------------------------------------------------------------------

  describe "nested children" do
    test "collects tags from deeply nested children" do
      leaf = node("html-button-response", "leaf-tag")
      middle = node("html-button-response", "", %{}, [leaf])
      root = node("html-button-response", "", %{}, [middle])

      result = DataTags.collect([root])
      assert [%{"tag" => "leaf-tag"}] = result
    end

    test "collects tags from both parent and child nodes" do
      child = node("html-button-response", "child-tag")
      parent = node("html-button-response", "parent-tag", %{}, [child])

      tags = DataTags.collect([parent]) |> Enum.map(& &1["tag"])
      assert "parent-tag" in tags
      assert "child-tag" in tags
    end

    test "survey questions from a nested survey node are included" do
      child = survey_node("nested-survey", [
        question("opinion", "radiogroup", choices: ["Good", "Bad"])
      ])

      parent = node("html-button-response", "", %{}, [child])

      [entry] = DataTags.collect([parent])
      assert entry["tag"] == "nested-survey"
      assert hd(entry["questions"])["choices"] == ["Good", "Bad"]
    end

    test "handles multiple siblings at the same level" do
      nodes = [
        node("html-button-response", "block-a"),
        node("html-button-response", "block-b"),
        survey_node("survey-c", [question("q1", "text")])
      ]

      tags = DataTags.collect(nodes) |> Enum.map(& &1["tag"])
      assert tags == ["block-a", "block-b", "survey-c"]
    end
  end
end
