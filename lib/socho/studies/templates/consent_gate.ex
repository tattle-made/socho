defmodule Socho.Studies.Templates.ConsentGate do
  @moduledoc false

  def definition do
    %{
      id: "consent_gate",
      name: "Consent Gate",
      description:
        "A Yes/No consent question that conditionally shows study content or a withdrawal message.",
      variables: [
        %{
          key: "consent_html",
          label: "Consent text",
          type: :text,
          default:
            "<p>Please read the following before participating.</p><p>Your data will be anonymised and used for research purposes only. Participation is voluntary and you may withdraw at any time.</p><p>Do you agree to participate?</p>"
        },
        %{
          key: "yes_label",
          label: "Yes button label",
          type: :text,
          default: "Yes, I agree to participate"
        },
        %{
          key: "no_label",
          label: "No button label",
          type: :text,
          default: "No, I do not wish to participate"
        },
        %{
          key: "withdrawal_html",
          label: "Withdrawal message",
          type: :text,
          default:
            "<p>Thank you for your time.</p><p>Since you did not consent to participate, the session is now complete. You may close this window.</p>"
        }
      ],
      build: fn vars ->
        consent_html = Map.get(vars, "consent_html", "")
        yes_label = Map.get(vars, "yes_label", "Yes, I agree to participate")
        no_label = Map.get(vars, "no_label", "No, I do not wish to participate")
        withdrawal_html = Map.get(vars, "withdrawal_html", "")

        # "Yes" is always button index 0, "No" is index 1.
        # The conditional_function uses response === 0 to check for consent.
        consented_fn =
          "const d = jsPsych.data.get().filter({ tag: \"consent\" }).last(1).values()[0];\nreturn d && d.response === 0;"

        withdrew_fn =
          "const d = jsPsych.data.get().filter({ tag: \"consent\" }).last(1).values()[0];\nreturn !d || d.response !== 0;"

        [
          # 1. Consent question
          %{
            node_type: "trial",
            plugin: "html-button-response",
            config: %{
              "stimulus" => consent_html,
              "choices" => [yes_label, no_label],
              "data_tag" => "consent",
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
          # 2. Study content — runs only if participant clicked "Yes" (response === 0).
          #    Add your study trials inside this timeline group.
          %{
            node_type: "timeline",
            plugin: nil,
            config: %{
              "timeline_variables" => [],
              "repetitions" => 1,
              "randomize_order" => false,
              "conditional_function" => consented_fn,
              "loop_function" => ""
            },
            extensions: %{},
            children: []
          },
          # 3. Withdrawal message — runs only if participant clicked "No".
          %{
            node_type: "timeline",
            plugin: nil,
            config: %{
              "timeline_variables" => [],
              "repetitions" => 1,
              "randomize_order" => false,
              "conditional_function" => withdrew_fn,
              "loop_function" => ""
            },
            extensions: %{},
            children: [
              %{
                node_type: "trial",
                plugin: "html-button-response",
                config: %{
                  "stimulus" => withdrawal_html,
                  "choices" => ["Close"],
                  "data_tag" => "",
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
              }
            ]
          }
        ]
      end
    }
  end
end
