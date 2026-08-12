defmodule Socho.Studies.Templates.LikertSurvey do
  @moduledoc false

  def definition do
    %{
      id: "likert_survey",
      name: "Likert Survey",
      description: "Multiple questions sharing a common rating scale.",
      variables: [
        %{
          key: "scale",
          label: "Scale options",
          type: :list,
          default: ["Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree"]
        },
        %{
          key: "prompts",
          label: "Questions",
          type: :list,
          default: ["Question 1"]
        }
      ],
      build: fn vars ->
        scale = (vars["scale"] || []) |> Enum.reject(&(&1 == ""))
        prompts = (vars["prompts"] || []) |> Enum.reject(&(&1 == ""))

        questions =
          Enum.map(prompts, fn prompt ->
            %{"prompt" => prompt, "labels" => scale, "required" => false, "name" => ""}
          end)

        [
          %{
            node_type: "trial",
            plugin: "survey-likert",
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
