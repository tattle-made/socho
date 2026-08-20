defmodule Socho.Studies.Templates.PairwiseImageCompare do
  @moduledoc false

  def definition do
    %{
      id: "pairwise_image_compare",
      name: "Pairwise Image Compare",
      description:
        "Shows explicitly defined image pairs in random order. Participants click to pick one image from each pair.",
      variables: [
        %{
          key: "pairs",
          label: "Image Pairs",
          type: :pair_list,
          default: [["https://example.com/image1.jpg", "https://example.com/image2.jpg"]]
        },
        %{
          key: "prompt",
          label: "Prompt (shown above each pair)",
          type: :text,
          default: "Which image do you prefer?"
        },
        %{key: "image_width", label: "Image width (px)", type: :int, default: "300"},
        %{key: "image_height", label: "Image height (px)", type: :int, default: "300"}
      ],
      build: fn vars ->
        pairs =
          (vars["pairs"] || [])
          |> Enum.reject(fn
            [a, b] -> a == "" && b == ""
            _ -> true
          end)

        prompt = Map.get(vars, "prompt", "")

        image_width =
          case Integer.parse(to_string(Map.get(vars, "image_width", "300"))) do
            {n, _} -> n
            :error -> 300
          end

        image_height =
          case Integer.parse(to_string(Map.get(vars, "image_height", "300"))) do
            {n, _} -> n
            :error -> 300
          end

        [
          %{
            node_type: "trial",
            plugin: "pairwise-compare",
            config: %{
              "pairs" => pairs,
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
