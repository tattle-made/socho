defmodule Socho.Studies.Templates.SimpleSurvey do
  @moduledoc false

  def definition do
    %{
      id: "simple_survey",
      name: "Simple Survey",
      description: "An open-ended question followed by a Likert scale item.",
      variables: [
        %{
          key: "preamble",
          label: "Survey preamble",
          type: :text,
          default: "<p>Please answer the following questions honestly.</p>"
        },
        %{
          key: "open_question",
          label: "Open-ended question",
          type: :text,
          default: "How are you feeling today?"
        },
        %{
          key: "likert_question",
          label: "Likert question",
          type: :text,
          default: "I feel comfortable using this app."
        }
      ],
      build: fn vars ->
        preamble = Map.get(vars, "preamble", "")
        open_q = Map.get(vars, "open_question", "")
        likert_q = Map.get(vars, "likert_question", "")

        [
          %{
            node_type: "trial",
            plugin: "survey-text",
            config: %{
              "questions" => [
                %{
                  "prompt" => open_q,
                  "placeholder" => "",
                  "rows" => 3,
                  "columns" => 40,
                  "required" => false,
                  "name" => "q1"
                }
              ],
              "randomize_question_order" => false,
              "preamble" => preamble,
              "button_label" => "Continue",
              "autocomplete" => false
            },
            extensions: %{},
            children: []
          },
          %{
            node_type: "trial",
            plugin: "survey-likert",
            config: %{
              "questions" => [
                %{
                  "prompt" => likert_q,
                  "labels" => [
                    "Strongly disagree",
                    "Disagree",
                    "Neutral",
                    "Agree",
                    "Strongly agree"
                  ],
                  "required" => false,
                  "name" => "q1"
                }
              ],
              "randomize_question_order" => false,
              "preamble" => "",
              "button_label" => "Continue",
              "autocomplete" => false
            },
            extensions: %{},
            children: []
          }
        ]
      end
    }
  end
end
