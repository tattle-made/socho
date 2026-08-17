Mix.install([{:jason, "~> 1.4"}])

defmodule IatScore do
  @rt_min 400
  @rt_max 10_000

  def run(path) do
    trials = path |> File.read!() |> Jason.decode!()

    IO.puts("=== IAT D-score calculator ===")
    IO.puts("File: #{path}")
    IO.puts("Total trials in file: #{length(trials)}")
    IO.puts("")

    print_embedded_summary(trials)
    print_trial_type_summary(trials)

    c1_practice = filter(trials, "combined1_practice")
    c1_test     = filter(trials, "combined1_test")
    c2_practice = filter(trials, "combined2_practice")
    c2_test     = filter(trials, "combined2_test")

    IO.puts("=== Trials after RT filter (#{@rt_min}–#{@rt_max} ms) ===")
    IO.puts("  combined1_practice : #{length(c1_practice)}")
    IO.puts("  combined1_test     : #{length(c1_test)}")
    IO.puts("  combined2_practice : #{length(c2_practice)}")
    IO.puts("  combined2_test     : #{length(c2_test)}")
    IO.puts("")

    if Enum.any?([c1_practice, c1_test, c2_practice, c2_test], &(&1 == [])) do
      IO.puts("ERROR: one or more blocks are empty — cannot compute D-score.")
      IO.puts("Check that the iat_type labels in the JSON match the expected values above.")
      System.halt(1)
    end

    mean_c1_practice = mean(rts(c1_practice))
    mean_c1_test     = mean(rts(c1_test))
    mean_c2_practice = mean(rts(c2_practice))
    mean_c2_test     = mean(rts(c2_test))

    # Overall means across practice+test (shown for reference)
    mean_c1 = mean(rts(c1_practice) ++ rts(c1_test))
    mean_c2 = mean(rts(c2_practice) ++ rts(c2_test))

    # Greenwald 2003: SD pooled within phase (practice together, test together)
    sd1 = sd(rts(c1_practice) ++ rts(c2_practice))
    sd2 = sd(rts(c1_test)     ++ rts(c2_test))

    d1 = (mean_c2_practice - mean_c1_practice) / sd1
    d2 = (mean_c2_test     - mean_c1_test)     / sd2
    d  = (d1 + d2) / 2

    IO.puts("=== Block means (ms) ===")
    IO.puts("  combined1_practice mean : #{fmt(mean_c1_practice)}")
    IO.puts("  combined1_test mean     : #{fmt(mean_c1_test)}")
    IO.puts("  combined2_practice mean : #{fmt(mean_c2_practice)}")
    IO.puts("  combined2_test mean     : #{fmt(mean_c2_test)}")
    IO.puts("")
    IO.puts("  mean_c1 (c1 practice+test) : #{fmt(mean_c1)}")
    IO.puts("  mean_c2 (c2 practice+test) : #{fmt(mean_c2)}")
    IO.puts("")
    IO.puts("=== Pooled SDs ===")
    IO.puts("  sd1 (practice pool) : #{fmt(sd1)}")
    IO.puts("  sd2 (test pool)     : #{fmt(sd2)}")
    IO.puts("")
    IO.puts("=== D-score components ===")
    IO.puts("  d1 (practice) : #{fmt(d1)}")
    IO.puts("  d2 (test)     : #{fmt(d2)}")
    IO.puts("")
    IO.puts("=== D-score : #{fmt(d)} ===")
    IO.puts("")
    IO.puts("Interpretation: >0.15 slight, >0.35 moderate, >0.65 strong association")
    IO.puts("Positive = cat1+att1 paired faster; negative = cat2+att1 paired faster")
  end

  defp filter(trials, type) do
    Enum.filter(trials, fn t ->
      t["iat_type"] == type and
        is_number(t["rt"]) and
        t["rt"] >= @rt_min and
        t["rt"] < @rt_max
    end)
  end

  defp rts(trials), do: Enum.map(trials, & &1["rt"])

  defp mean([]), do: 0.0
  defp mean(vals) do
    Enum.sum(vals) / length(vals)
  end

  defp sd([]), do: 0.0
  defp sd([_]), do: 0.0
  defp sd(vals) do
    m = mean(vals)
    # jsPsych uses sample SD (N-1), matching this for consistency
    variance = Enum.sum(Enum.map(vals, fn v -> (v - m) * (v - m) end)) / (length(vals) - 1)
    :math.sqrt(variance)
  end

  defp fmt(n), do: :erlang.float_to_binary(n / 1, decimals: 4)

  defp print_embedded_summary(trials) do
    case Enum.find(trials, &(&1["iat_type"] == "iat_summary")) do
      nil ->
        IO.puts("(no iat_summary row found — file was downloaded before the push fix)")
        IO.puts("")
      row ->
        IO.puts("=== Embedded iat_summary (from file) ===")
        IO.puts("  d_score : #{fmt(row["d_score"])}")
        IO.puts("  mean_c1 : #{fmt(row["mean_c1"])}")
        IO.puts("  mean_c2 : #{fmt(row["mean_c2"])}")
        IO.puts("")
    end
  end

  defp print_trial_type_summary(trials) do
    IO.puts("=== Trial types found in file ===")

    trials
    |> Enum.group_by(& &1["iat_type"])
    |> Enum.sort_by(fn {k, _} -> k end)
    |> Enum.each(fn {type, ts} ->
      rts = ts |> Enum.map(& &1["rt"]) |> Enum.filter(&is_number/1)
      rt_info = if rts == [], do: "(no rt)", else: "rt #{Enum.min(rts)}–#{Enum.max(rts)} ms"
      IO.puts("  #{type || "nil"} : #{length(ts)} trials  #{rt_info}")
    end)

    IO.puts("")
  end
end

case System.argv() do
  [path] ->
    if File.exists?(path) do
      IatScore.run(path)
    else
      IO.puts("File not found: #{path}")
      System.halt(1)
    end

  _ ->
    IO.puts("Usage: elixir scripts/iat_score.exs <path/to/iat_data.json>")
    System.halt(1)
end
