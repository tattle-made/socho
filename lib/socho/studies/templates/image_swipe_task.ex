defmodule Socho.Studies.Templates.ImageSwipeTask do
  @moduledoc false

  def definition do
    %{
      id: "image_swipe_task",
      name: "Image Swipe Task",
      description:
        "Participants swipe images left or right. Add your image URLs and configure labels.",
      variables: [
        %{
          key: "image_urls",
          label: "Image URLs",
          type: :list,
          default: ["https://example.com/image1.jpg"]
        },
        %{key: "left_label", label: "Left label", type: :text, default: "No"},
        %{key: "right_label", label: "Right label", type: :text, default: "Yes"},
        %{
          key: "instructions_html",
          label: "Instructions",
          type: :text,
          default: "In this next exercise, you will be shown two images and you will be asked to make a choice. Swipe Left if you like the image and Swipe Right if you don't"
       },
        %{
          key: "prompt",
          label: "Prompt",
          type: :text,
          default: "Swipe each image left or right to respond."
        }
      ],
      build: fn vars ->
        image_urls = (vars["image_urls"] || ["https://example.com/image1.jpg"]) |> Enum.reject(&(&1 == ""))
        left_label = Map.get(vars, "left_label", "No")
        right_label = Map.get(vars, "right_label", "Yes")
        instructions = Map.get(vars, "instructions_html", "")
        prompt = Map.get(vars, "prompt", "")

        [
          %{
            node_type: "trial",
            plugin: "instructions",
            config: %{
              "pages" => [instructions],
              "allow_backward" => true,
              "allow_keys" => true,
              "show_clickable_nav" => true,
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
              "timeline_variables" => Enum.map(image_urls, &%{"stimulus" => &1}),
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
                  "prompt" => prompt
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
