defmodule Socho.Studies.Templates.ImageSwipeTask do
  @moduledoc false

  def definition do
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
