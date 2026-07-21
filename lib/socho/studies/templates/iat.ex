defmodule Socho.Studies.Templates.Iat do
  @moduledoc false

  def definition do
    %{
      id: "iat",
      name: "Implicit Association Test (IAT)",
      description:
        "7-block IAT measuring implicit associations between two categories and two attributes using image stimuli.",
      variables: [
        %{key: "cat1_label", label: "Category 1 label", type: :text, default: "Category A"},
        %{
          key: "cat1_images",
          label: "Category 1 stimuli (one image URL or word per line)",
          type: :text,
          default: "https://example.com/cat1_1.jpg\nhttps://example.com/cat1_2.jpg"
        },
        %{key: "cat2_label", label: "Category 2 label", type: :text, default: "Category B"},
        %{
          key: "cat2_images",
          label: "Category 2 stimuli (one image URL or word per line)",
          type: :text,
          default: "https://example.com/cat2_1.jpg\nhttps://example.com/cat2_2.jpg"
        },
        %{key: "att1_label", label: "Attribute 1 label", type: :text, default: "Pleasant"},
        %{
          key: "att1_images",
          label: "Attribute 1 stimuli (one image URL or word per line)",
          type: :text,
          default: "Pleasant\nJoyful\nHappy"
        },
        %{key: "att2_label", label: "Attribute 2 label", type: :text, default: "Unpleasant"},
        %{
          key: "att2_images",
          label: "Attribute 2 stimuli (one image URL or word per line)",
          type: :text,
          default: "Unpleasant\nSad\nAngry"
        },
        %{
          key: "instructions_html",
          label: "General instructions",
          type: :text,
          default:
            "<p>In this task you will categorize items as quickly and accurately as possible.</p><p>Use the <strong>E</strong> key or <strong>touch the left side</strong> of the screen for items on the left. Use the <strong>I</strong> key or <strong>touch the right side</strong> of the screen for items on the right.</p><p>If you press the wrong key, a red X will appear — press any key to continue.</p><p>Press the right arrow key, or tap the bottom of the screen, to begin.</p>"
        }
      ],
      build: fn vars ->
        cat1_label = Map.get(vars, "cat1_label", "Category A")
        cat2_label = Map.get(vars, "cat2_label", "Category B")
        att1_label = Map.get(vars, "att1_label", "Pleasant")
        att2_label = Map.get(vars, "att2_label", "Unpleasant")
        instructions = Map.get(vars, "instructions_html", "")

        parse_lines = fn text ->
          text
          |> String.split("\n")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
        end

        cat1_images = parse_lines.(Map.get(vars, "cat1_images", ""))
        cat2_images = parse_lines.(Map.get(vars, "cat2_images", ""))
        att1_images = parse_lines.(Map.get(vars, "att1_images", ""))
        att2_images = parse_lines.(Map.get(vars, "att2_images", ""))

        is_url = fn item ->
          String.starts_with?(item, "http://") or String.starts_with?(item, "https://")
        end

        to_stimulus = fn item ->
          if is_url.(item), do: "<img src='#{item}'>", else: item
        end

        make_stim_vars = fn item_list, association ->
          Enum.map(item_list, fn item ->
            %{"stimulus" => to_stimulus.(item), "stim_key_association" => association}
          end)
        end

        block_intro = fn html ->
          %{
            node_type: "trial",
            plugin: "html-button-response",
            config: %{
              "stimulus" => html,
              "choices" => ["Begin Block"],
              "prompt" => "",
              "button_layout" => "grid",
              "grid_rows" => "1",
              "grid_columns" => "",
              "response_ends_trial" => true,
              "enable_button_after" => 0
            },
            extensions: %{
              "touchscreen-buttons" => %{
                "enabled" => true,
                "buttons" => [
                  %{"key" => "ArrowRight", "preset" => "fill_bottom", "label" => "", "color" => "#FF9B91"}
                ]
              }
            },
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
                plugin: "iat-html",
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
                extensions: %{
                  "touchscreen-buttons" => %{
                    "enabled" => true,
                    "buttons" => [
                      %{"key" => "e", "preset" => "left_middle",  "label" => "←", "color" => "#FF9B91"},
                      %{"key" => "i", "preset" => "right_middle", "label" => "→", "color" => "#FF9B91"}
                    ]
                  }
                },
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

        # Version A: compatible-first (cat1 left in combined blocks)
        version_a_children = [
          block_intro.(
            "<h2>Category Practice</h2><p>Categorize each image as <strong>#{cat1_label}</strong> (press <strong>E</strong> or touch left) or <strong>#{cat2_label}</strong> (press <strong>I</strong> or touch right).</p>"
          ),
          iat_block.(cat_vars, [cat1_label], [cat2_label], 2),
          block_intro.(
            "<h2>Attribute Practice</h2><p>Categorize each image as <strong>#{att1_label}</strong> (press <strong>E</strong> or touch left) or <strong>#{att2_label}</strong> (press <strong>I</strong> or touch right).</p>"
          ),
          iat_block.(att_vars, [att1_label], [att2_label], 2),
          block_intro.(
            "<h2>Combined Practice</h2><p>Press <strong>E</strong> or touch left for <strong>#{cat1_label}</strong> or <strong>#{att1_label}</strong>.</p><p>Press <strong>I</strong> or touch right for <strong>#{cat2_label}</strong> or <strong>#{att2_label}</strong>.</p>"
          ),
          iat_block.(combined1_vars, [cat1_label, att1_label], [cat2_label, att2_label], 2),
          block_intro.(
            "<h2>Combined Test</h2><p>Press <strong>E</strong> or touch left for <strong>#{cat1_label}</strong> or <strong>#{att1_label}</strong>.</p><p>Press <strong>I</strong> or touch right for <strong>#{cat2_label}</strong> or <strong>#{att2_label}</strong>.</p><p>Go as fast as you can while remaining accurate.</p>"
          ),
          iat_block.(combined1_vars, [cat1_label, att1_label], [cat2_label, att2_label], 4),
          block_intro.(
            "<h2>Category Reversed Practice</h2><p>The categories have switched sides. Press <strong>E</strong> or touch left for <strong>#{cat2_label}</strong> and press <strong>I</strong> or touch right for <strong>#{cat1_label}</strong>.</p>"
          ),
          iat_block.(cat_rev_vars, [cat2_label], [cat1_label], 2),
          block_intro.(
            "<h2>Combined Reversed Practice</h2><p>Press <strong>E</strong> or touch left for <strong>#{cat2_label}</strong> or <strong>#{att1_label}</strong>.</p><p>Press <strong>I</strong> or touch right for <strong>#{cat1_label}</strong> or <strong>#{att2_label}</strong>.</p>"
          ),
          iat_block.(combined2_vars, [cat2_label, att1_label], [cat1_label, att2_label], 2),
          block_intro.(
            "<h2>Combined Reversed Test</h2><p>Press <strong>E</strong> or touch left for <strong>#{cat2_label}</strong> or <strong>#{att1_label}</strong>.</p><p>Press <strong>I</strong> or touch right for <strong>#{cat1_label}</strong> or <strong>#{att2_label}</strong>.</p><p>Go as fast as you can while remaining accurate.</p>"
          ),
          iat_block.(combined2_vars, [cat2_label, att1_label], [cat1_label, att2_label], 4)
        ]

        # Version B: incompatible-first (cat2 left in combined blocks)
        version_b_children = [
          block_intro.(
            "<h2>Category Reversed Practice</h2><p>Categorize each image as <strong>#{cat2_label}</strong> (press <strong>E</strong> or touch left) or <strong>#{cat1_label}</strong> (press <strong>I</strong> or touch right).</p>"
          ),
          iat_block.(cat_rev_vars, [cat2_label], [cat1_label], 2),
          block_intro.(
            "<h2>Attribute Practice</h2><p>Categorize each image as <strong>#{att1_label}</strong> (press <strong>E</strong> or touch left) or <strong>#{att2_label}</strong> (press <strong>I</strong> or touch right).</p>"
          ),
          iat_block.(att_vars, [att1_label], [att2_label], 2),
          block_intro.(
            "<h2>Combined Reversed Practice</h2><p>Press <strong>E</strong> or touch left for <strong>#{cat2_label}</strong> or <strong>#{att1_label}</strong>.</p><p>Press <strong>I</strong> or touch right for <strong>#{cat1_label}</strong> or <strong>#{att2_label}</strong>.</p>"
          ),
          iat_block.(combined2_vars, [cat2_label, att1_label], [cat1_label, att2_label], 2),
          block_intro.(
            "<h2>Combined Reversed Test</h2><p>Press <strong>E</strong> or touch left for <strong>#{cat2_label}</strong> or <strong>#{att1_label}</strong>.</p><p>Press <strong>I</strong> or touch right for <strong>#{cat1_label}</strong> or <strong>#{att2_label}</strong>.</p><p>Go as fast as you can while remaining accurate.</p>"
          ),
          iat_block.(combined2_vars, [cat2_label, att1_label], [cat1_label, att2_label], 4),
          block_intro.(
            "<h2>Category Practice</h2><p>Categorize each image as <strong>#{cat1_label}</strong> (press <strong>E</strong> or touch left) or <strong>#{cat2_label}</strong> (press <strong>I</strong> or touch right).</p>"
          ),
          iat_block.(cat_vars, [cat1_label], [cat2_label], 2),
          block_intro.(
            "<h2>Combined Practice</h2><p>Press <strong>E</strong> or touch left for <strong>#{cat1_label}</strong> or <strong>#{att1_label}</strong>.</p><p>Press <strong>I</strong> or touch right for <strong>#{cat2_label}</strong> or <strong>#{att2_label}</strong>.</p>"
          ),
          iat_block.(combined1_vars, [cat1_label, att1_label], [cat2_label, att2_label], 2),
          block_intro.(
            "<h2>Combined Test</h2><p>Press <strong>E</strong> or touch left for <strong>#{cat1_label}</strong> or <strong>#{att1_label}</strong>.</p><p>Press <strong>I</strong> or touch right for <strong>#{cat2_label}</strong> or <strong>#{att2_label}</strong>.</p><p>Go as fast as you can while remaining accurate.</p>"
          ),
          iat_block.(combined1_vars, [cat1_label, att1_label], [cat2_label, att2_label], 4)
        ]

        all_images =
          (cat1_images ++ cat2_images ++ att1_images ++ att2_images)
          |> Enum.filter(is_url)

        [
          %{
            node_type: "trial",
            plugin: "preload",
            config: %{"images" => all_images, "auto_preload" => false},
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
          %{
            node_type: "counterbalanced_group",
            plugin: nil,
            config: %{"split" => length(version_a_children)},
            extensions: %{},
            children: version_a_children ++ version_b_children
          }
        ]
      end
    }
  end
end
