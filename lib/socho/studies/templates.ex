defmodule Socho.Studies.Templates do
  @moduledoc false

  def all do
    [consent_and_instructions(), simple_survey(), image_swipe_task(), iat()]
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

  defp iat do
    %{
      id: "iat",
      name: "Implicit Association Test (IAT)",
      description:
        "7-block IAT measuring implicit associations between two categories and two attributes using image stimuli.",
      variables: [
        %{key: "cat1_label", label: "Category 1 label", type: :text, default: "Category A"},
        %{
          key: "cat1_images",
          label: "Category 1 images (one URL per line)",
          type: :text,
          default: "https://example.com/cat1_1.jpg\nhttps://example.com/cat1_2.jpg"
        },
        %{key: "cat2_label", label: "Category 2 label", type: :text, default: "Category B"},
        %{
          key: "cat2_images",
          label: "Category 2 images (one URL per line)",
          type: :text,
          default: "https://example.com/cat2_1.jpg\nhttps://example.com/cat2_2.jpg"
        },
        %{key: "att1_label", label: "Attribute 1 label", type: :text, default: "Pleasant"},
        %{
          key: "att1_images",
          label: "Attribute 1 images (one URL per line)",
          type: :text,
          default: "https://example.com/att1_1.jpg\nhttps://example.com/att1_2.jpg"
        },
        %{key: "att2_label", label: "Attribute 2 label", type: :text, default: "Unpleasant"},
        %{
          key: "att2_images",
          label: "Attribute 2 images (one URL per line)",
          type: :text,
          default: "https://example.com/att2_1.jpg\nhttps://example.com/att2_2.jpg"
        },
        %{
          key: "instructions_html",
          label: "General instructions",
          type: :text,
          default:
            "<p>In this task you will categorize items as quickly and accurately as possible.</p><p>Use the <strong>E</strong> key for items on the left and the <strong>I</strong> key for items on the right.</p><p>If you press the wrong key, a red X will appear — press any key to continue.</p><p>Press the right arrow key to begin.</p>"
        }
      ],
      build: fn vars ->
        cat1_label = Map.get(vars, "cat1_label", "Category A")
        cat2_label = Map.get(vars, "cat2_label", "Category B")
        att1_label = Map.get(vars, "att1_label", "Pleasant")
        att2_label = Map.get(vars, "att2_label", "Unpleasant")
        instructions = Map.get(vars, "instructions_html", "")

        parse_urls = fn text ->
          text
          |> String.split("\n")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
        end

        cat1_images = parse_urls.(Map.get(vars, "cat1_images", ""))
        cat2_images = parse_urls.(Map.get(vars, "cat2_images", ""))
        att1_images = parse_urls.(Map.get(vars, "att1_images", ""))
        att2_images = parse_urls.(Map.get(vars, "att2_images", ""))

        make_stim_vars = fn image_list, association ->
          Enum.map(image_list, &%{"stimulus" => &1, "stim_key_association" => association})
        end

        block_intro = fn html ->
          %{
            node_type: "trial",
            plugin: "html-button-response",
            config: %{
              "stimulus" => html,
              "choices" => ["Begin Block"],
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
        end

        iat_block = fn timeline_vars, left_labels, right_labels, reps ->
          %{
            node_type: "timeline",
            plugin: nil,
            config: %{
              "timeline_variables" => timeline_vars,
              "repetitions" => reps,
              "randomize_order" => true
            },
            extensions: %{},
            children: [
              %{
                node_type: "trial",
                plugin: "iat-image",
                config: %{
                  "stimulus" => "{{stimulus}}",
                  "stim_key_association" => "{{stim_key_association}}",
                  "left_category_key" => "e",
                  "right_category_key" => "i",
                  "left_category_label" => left_labels,
                  "right_category_label" => right_labels,
                  "display_feedback" => true,
                  "html_when_wrong" =>
                    "<span style='color: red; font-size: 80px'>X</span>",
                  "bottom_instructions" =>
                    "<p>If you press the wrong key, a red X will appear. Press any key to continue.</p>",
                  "force_correct_key_press" => false,
                  "response_ends_trial" => true,
                  "trial_duration" => nil
                },
                extensions: %{},
                children: []
              }
            ]
          }
        end

        cat_vars =
          make_stim_vars.(cat1_images, "left") ++
            make_stim_vars.(cat2_images, "right")

        att_vars =
          make_stim_vars.(att1_images, "left") ++
            make_stim_vars.(att2_images, "right")

        combined1_vars =
          make_stim_vars.(cat1_images, "left") ++
            make_stim_vars.(att1_images, "left") ++
            make_stim_vars.(cat2_images, "right") ++
            make_stim_vars.(att2_images, "right")

        cat_rev_vars =
          make_stim_vars.(cat2_images, "left") ++
            make_stim_vars.(cat1_images, "right")

        combined2_vars =
          make_stim_vars.(cat2_images, "left") ++
            make_stim_vars.(att1_images, "left") ++
            make_stim_vars.(cat1_images, "right") ++
            make_stim_vars.(att2_images, "right")

        [
          %{
            node_type: "trial",
            plugin: "instructions",
            config: %{
              "pages" => [instructions],
              "key_forward" => "ArrowRight",
              "key_backward" => "ArrowLeft",
              "allow_backward" => false,
              "allow_keys" => true,
              "show_clickable_nav" => false,
              "show_page_number" => false,
              "page_label" => "Page",
              "button_label_previous" => "Previous",
              "button_label_next" => "Next"
            },
            extensions: %{},
            children: []
          },
          block_intro.(
            "<h2>Block 1 of 7: Category Practice</h2><p>Categorize each image as <strong>#{cat1_label}</strong> (press <strong>E</strong>) or <strong>#{cat2_label}</strong> (press <strong>I</strong>).</p>"
          ),
          iat_block.(cat_vars, [cat1_label], [cat2_label], 2),
          block_intro.(
            "<h2>Block 2 of 7: Attribute Practice</h2><p>Categorize each image as <strong>#{att1_label}</strong> (press <strong>E</strong>) or <strong>#{att2_label}</strong> (press <strong>I</strong>).</p>"
          ),
          iat_block.(att_vars, [att1_label], [att2_label], 2),
          block_intro.(
            "<h2>Block 3 of 7: Combined Practice</h2><p>Press <strong>E</strong> for <strong>#{cat1_label}</strong> or <strong>#{att1_label}</strong>.</p><p>Press <strong>I</strong> for <strong>#{cat2_label}</strong> or <strong>#{att2_label}</strong>.</p>"
          ),
          iat_block.(combined1_vars, [cat1_label, att1_label], [cat2_label, att2_label], 2),
          block_intro.(
            "<h2>Block 4 of 7: Combined Test</h2><p>Press <strong>E</strong> for <strong>#{cat1_label}</strong> or <strong>#{att1_label}</strong>.</p><p>Press <strong>I</strong> for <strong>#{cat2_label}</strong> or <strong>#{att2_label}</strong>.</p><p>Go as fast as you can while remaining accurate.</p>"
          ),
          iat_block.(combined1_vars, [cat1_label, att1_label], [cat2_label, att2_label], 4),
          block_intro.(
            "<h2>Block 5 of 7: Category Reversed Practice</h2><p>The categories have switched sides. Press <strong>E</strong> for <strong>#{cat2_label}</strong> and <strong>I</strong> for <strong>#{cat1_label}</strong>.</p>"
          ),
          iat_block.(cat_rev_vars, [cat2_label], [cat1_label], 2),
          block_intro.(
            "<h2>Block 6 of 7: Combined Reversed Practice</h2><p>Press <strong>E</strong> for <strong>#{cat2_label}</strong> or <strong>#{att1_label}</strong>.</p><p>Press <strong>I</strong> for <strong>#{cat1_label}</strong> or <strong>#{att2_label}</strong>.</p>"
          ),
          iat_block.(combined2_vars, [cat2_label, att1_label], [cat1_label, att2_label], 2),
          block_intro.(
            "<h2>Block 7 of 7: Combined Reversed Test</h2><p>Press <strong>E</strong> for <strong>#{cat2_label}</strong> or <strong>#{att1_label}</strong>.</p><p>Press <strong>I</strong> for <strong>#{cat1_label}</strong> or <strong>#{att2_label}</strong>.</p><p>Go as fast as you can while remaining accurate.</p>"
          ),
          iat_block.(combined2_vars, [cat2_label, att1_label], [cat1_label, att2_label], 4)
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
