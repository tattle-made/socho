defmodule Socho.LoadTest.IAT do
  @moduledoc """
  The IAT study the load test runs, and the results a participant posts.

  The seed creates studies from `nodes/0`. The scenario posts `submission/0`.
  Randomness is seeded, so the submission is the same on every call.
  """

  alias Socho.Studies.Templates

  @random_seed {31, 31, 31}
  @error_rate 0.07
  @reaction_time_sd_ms 180
  @min_reaction_time_ms 300
  @max_reaction_time_ms 3_000
  @gap_between_trials_ms 250
  @plugin_version "2.0.0"

  # Tree: preload, instructions, a group of versions, results
  def nodes do
    iat = Templates.get("iat")
    defaults = Map.new(iat.variables, &{&1.key, &1.default})

    iat.build.(
      Map.merge(defaults, %{
        "cat1_label" => "Flowers",
        "cat1_images" => image_urls("flower"),
        "cat2_label" => "Insects",
        "cat2_images" => image_urls("insect"),
        "att1_images" => "Joy\nLove\nPeace\nHappy\nLaughter",
        "att2_images" => "Agony\nTerrible\nHorrible\nNasty\nEvil"
      })
    )
  end

  defp image_urls(name) do
    Enum.map_join(1..5, "\n", &"https://picsum.photos/seed/#{name}#{&1}/300")
  end

  # Fake the rows jsPsych posts when a participant finishes the IAT
  def submission do
    :rand.seed(:exsss, @random_seed)
    [_preload, _instructions, versions, _results] = nodes()
    iat_trials = Enum.flat_map(version_aa(versions), &trials_for/1)

    ([preload_trial(), instructions_trial()] ++ iat_trials ++ [results_trial()])
    |> add_timing()
    |> Kernel.++([iat_summary()])
  end

  # A participant sees one version, so take the first
  defp version_aa(versions) do
    Enum.take(versions.children, hd(versions.config["group_sizes"]))
  end

  # IAT block: one row per stimulus, shuffled, repeated
  defp trials_for(%{node_type: "timeline", config: config}) do
    iat_type = config["data"]["iat_type"]

    for _ <- 1..config["repetitions"], variable <- Enum.shuffle(config["timeline_variables"]) do
      iat_trial(variable, iat_type)
    end
  end

  # Instruction screen: one row
  defp trials_for(%{plugin: "html-button-response", config: config}) do
    [
      %{
        "trial_type" => "html-button-response",
        "stimulus" => config["stimulus"],
        "response" => 0,
        "rt" => Enum.random(1_500..6_000)
      }
    ]
  end

  # One IAT answer. 7% of answers (@error_rate) press the wrong key
  defp iat_trial(variable, iat_type) do
    expected = expected_key(variable["stim_key_association"])
    correct? = :rand.uniform() > @error_rate

    %{
      "trial_type" => "iat-html",
      "stimulus" => variable["stimulus"],
      "response" => if(correct?, do: expected, else: other_key(expected)),
      "correct" => correct?,
      "rt" => reaction_time(iat_type),
      "iat_type" => iat_type
    }
  end

  defp expected_key("left"), do: "e"
  defp expected_key(_right), do: "i"

  defp other_key("e"), do: "i"
  defp other_key("i"), do: "e"

  # Bell curve around the block's mean, kept within 300ms-3s
  defp reaction_time(iat_type) do
    (mean_reaction_time(iat_type) + :rand.normal() * @reaction_time_sd_ms)
    |> round()
    |> max(@min_reaction_time_ms)
    |> min(@max_reaction_time_ms)
  end

  defp mean_reaction_time("combined1" <> _block), do: 750
  defp mean_reaction_time("combined2" <> _block), do: 900
  defp mean_reaction_time(_iat_type), do: 700

  # Fixed rows for the screens around the IAT blocks
  defp preload_trial do
    %{
      "trial_type" => "preload",
      "success" => true,
      "timeout" => false,
      "failed_images" => [],
      "failed_audio" => [],
      "failed_video" => [],
      "rt" => 412
    }
  end

  defp instructions_trial do
    %{
      "trial_type" => "instructions",
      "view_history" => [%{"page_index" => 0, "viewing_time" => 8213}],
      "rt" => 8213
    }
  end

  defp results_trial do
    %{
      "trial_type" => "html-button-response",
      "stimulus" => "<h2>Your results</h2><p>D-score: 0.42</p>",
      "response" => 0,
      "rt" => 3120
    }
  end

  # Hardcoded scores: they don't match the fake trials
  defp iat_summary do
    %{"iat_type" => "iat_summary", "d_score" => 0.42, "mean_c1" => 771.98, "mean_c2" => 932.94}
  end

  # Add trial_index and a running time_elapsed, like jsPsych
  defp add_timing(trials) do
    {timed_trials, _elapsed_ms} =
      trials
      |> Enum.with_index()
      |> Enum.map_reduce(0, fn {trial, index}, elapsed_ms ->
        elapsed_ms = elapsed_ms + trial["rt"] + @gap_between_trials_ms

        timing = %{
          "trial_index" => index,
          "time_elapsed" => elapsed_ms,
          "plugin_version" => @plugin_version
        }

        {Map.merge(trial, timing), elapsed_ms}
      end)

    timed_trials
  end
end
