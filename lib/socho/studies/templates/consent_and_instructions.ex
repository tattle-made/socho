defmodule Socho.Studies.Templates.ConsentAndInstructions do
  @moduledoc false

  def definition do
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
end
