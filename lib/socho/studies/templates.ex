defmodule Socho.Studies.Templates do
  @moduledoc false

  def all do
    [consent_and_instructions(), simple_survey(), image_swipe_task()]
  end

  def get(id), do: Enum.find(all(), &(&1.id == id))

  # ── Template definitions ────────────────────────────────────────────────────

  defp consent_and_instructions do
    %{
      id: "consent_and_instructions",
      name: "Consent & Instructions",
      description: "Opens with fullscreen mode, a consent form, then multi-page instructions.",
      variables: [
        %{
          key: "consent_html",
          label: "Consent text",
          type: :text,
          default:
            "<p>Please read the following before participating.</p><p>Your data will be kept confidential.</p>"
        },
        %{
          key: "instructions_html",
          label: "Instructions",
          type: :text,
          default: "<p>In this study you will...</p>"
        }
      ],
      build: fn vars ->
        consent = Map.get(vars, "consent_html", "")
        instructions = Map.get(vars, "instructions_html", "")

        [
          %{
            node_type: "trial",
            plugin: "fullscreen",
            config: %{
              "fullscreen_mode" => true,
              "message" => "<p>This study will switch to fullscreen. Click to continue.</p>",
              "button_label" => "Continue",
              "delay_after" => 1000
            },
            extensions: %{},
            children: []
          },
          %{
            node_type: "trial",
            plugin: "html-button-response",
            config: %{
              "stimulus" => consent,
              "choices" => ["I agree to participate"],
              "prompt" => "",
              "stimulus_duration" => "",
              "trial_duration" => "",
              "button_layout" => "grid",
              "grid_rows" => "1",
              "grid_columns" => "",
              "response_ends_trial" => true,
              "enable_button_after" => 0
            },
            extensions: %{},
            children: []
          },
          %{
            node_type: "trial",
            plugin: "instructions",
            config: %{
              "pages" => [instructions],
              "key_forward" => "ArrowRight",
              "key_backward" => "ArrowLeft",
              "allow_backward" => true,
              "allow_keys" => true,
              "show_clickable_nav" => false,
              "show_page_number" => false,
              "page_label" => "Page",
              "button_label_previous" => "Previous",
              "button_label_next" => "Next"
            },
            extensions: %{},
            children: []
          }
        ]
      end
    }
  end

  defp simple_survey do
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

  defp image_swipe_task do
    %{
      id: "image_swipe_task",
      name: "Image Swipe Task",
      description:
        "Participants swipe images left or right. Edit the timeline variables to add your image URLs.",
      variables: [
        %{key: "left_label", label: "Left label", type: :text, default: "No"},
        %{key: "right_label", label: "Right label", type: :text, default: "Yes"},
        %{
          key: "instructions_html",
          label: "Instructions",
          type: :text,
          default: "<p>Swipe each image left or right to respond.</p>"
        }
      ],
      build: fn vars ->
        left_label = Map.get(vars, "left_label", "No")
        right_label = Map.get(vars, "right_label", "Yes")
        instructions = Map.get(vars, "instructions_html", "")

        [
          %{
            node_type: "trial",
            plugin: "instructions",
            config: %{
              "pages" => [instructions],
              "allow_backward" => true,
              "allow_keys" => true,
              "show_clickable_nav" => false,
              "show_page_number" => false,
              "key_forward" => "ArrowRight",
              "key_backward" => "ArrowLeft",
              "page_label" => "Page",
              "button_label_previous" => "Previous",
              "button_label_next" => "Next"
            },
            extensions: %{},
            children: []
          },
          %{
            node_type: "timeline",
            plugin: nil,
            config: %{
              "timeline_variables" => [%{"stimulus" => "https://example.com/image1.jpg"}],
              "repetitions" => 1,
              "randomize_order" => false
            },
            extensions: %{},
            children: [
              %{
                node_type: "trial",
                plugin: "image-swipe",
                config: %{
                  "stimulus" => "{{stimulus}}",
                  "left_label" => left_label,
                  "right_label" => right_label,
                  "show_buttons" => true,
                  "image_width" => 360,
                  "image_height" => 360,
                  "swipe_threshold" => 80,
                  "prompt" => ""
                },
                extensions: %{},
                children: []
              }
            ]
          }
        ]
      end
    }
  end
end
