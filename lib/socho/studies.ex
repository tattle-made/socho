defmodule Socho.Studies do
  import Ecto.Query

  alias Socho.Repo
  alias Socho.Studies.{Study, Trial}

  def get_study!(id) do
    Study
    |> Repo.get!(id)
    |> Repo.preload(trials: from(t in Trial, order_by: t.position))
  end

  def create_study_with_trials(title, trials) do
    Repo.transaction(fn ->
      study =
        %Study{}
        |> Study.changeset(%{title: title, status: :draft})
        |> Repo.insert!()

      trials
      |> Enum.with_index(1)
      |> Enum.each(fn {%{plugin: plugin, config: config}, position} ->
        %Trial{}
        |> Trial.changeset(%{
          study_id: study.id,
          position: position,
          plugin: plugin,
          config: config
        })
        |> Repo.insert!()
      end)

      get_study!(study.id)
    end)
  end
end
