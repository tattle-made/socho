defmodule Socho.Studies.Templates.PairwiseImageCompare do
  @moduledoc false

  def definition do
    %{
      id: "pairwise_image_compare",
      name: "Pairwise Image Compare",
      description:
        "Shuffles a list of images and shows them as sequential pairs. Participants click to pick one image from each pair.",
      variables: [
        %{
          key: "image_urls",
          label: "Image URLs",
          type: :list,
          default: ["https://example.com/image1.jpg", "https://example.com/image2.jpg"]
        },
        %{
          key: "prompt",
          label: "Prompt (shown above each pair)",
          type: :text,
          default: "<p>Which image do you prefer?</p>"
        },
        %{key: "image_width", label: "Image width (px)", type: :text, default: "300"},
        %{key: "image_height", label: "Image height (px)", type: :text, default: "300"}
      ],
      build: fn vars ->
        image_urls =
          (vars["image_urls"] || [])
          |> Enum.reject(&(&1 == ""))

        prompt = Map.get(vars, "prompt", "")

        image_width =
          case Integer.parse(Map.get(vars, "image_width", "300")) do
            {n, _} -> n
            :error -> 300
          end

        image_height =
          case Integer.parse(Map.get(vars, "image_height", "300")) do
            {n, _} -> n
            :error -> 300
          end

        [
          %{
            node_type: "trial",
            plugin: "pairwise-compare",
            config: %{
              "images" => image_urls,
              "prompt" => prompt,
              "image_width" => image_width,
              "image_height" => image_height
            },
            extensions: %{},
            children: []
          }
        ]
      end
    }
  end
end
