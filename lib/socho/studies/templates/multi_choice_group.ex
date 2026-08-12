defmodule Socho.Studies.Templates.MultiChoiceGroup do
  @moduledoc false

  def definition do
    %{
      id: "multi_choice_group",
      name: "Multi Choice Group",
      description: "Multiple questions sharing a common set of answer choices.",
      variables: [
        %{
          key: "choices",
          label: "Answer choices",
          type: :list,
          default: ["Option A", "Option B", "Option C"]
        },
        %{
          key: "prompts",
          label: "Questions",
          type: :list,
          default: ["Question 1"]
        }
      ],
      build: fn vars ->
        choices = (vars["choices"] || []) |> Enum.reject(&(&1 == ""))
        prompts = (vars["prompts"] || []) |> Enum.reject(&(&1 == ""))

        questions =
          Enum.map(prompts, fn prompt ->
            %{"prompt" => prompt, "options" => choices, "required" => false, "horizontal" => false, "name" => ""}
          end)

        [
          %{
            node_type: "trial",
            plugin: "survey-multi-choice",
            config: %{
              "questions" => questions,
              "randomize_question_order" => false,
              "preamble" => "",
              "button_label" => "Continue",
              "autocomplete" => false,
              "data_tag" => ""
            },
            extensions: %{},
            children: []
          }
        ]
      end
    }
  end
end
