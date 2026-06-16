defmodule Socho.Studies do
  import Ecto.Query

  alias Socho.Repo
  alias Socho.Studies.{Study, Trial}

  def list_studies do
    Study
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

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

      insert_trials(study.id, trials)
      get_study!(study.id)
    end)
  end

  def update_study_with_trials(id, title, trials) do
    Repo.transaction(fn ->
      study = Repo.get!(Study, id)

      study
      |> Study.changeset(%{title: title})
      |> Repo.update!()

      Repo.delete_all(from(t in Trial, where: t.study_id == ^id))
      insert_trials(id, trials)
      get_study!(id)
    end)
  end

  defp insert_trials(study_id, trials) do
    trials
    |> Enum.with_index(1)
    |> Enum.each(fn {%{plugin: plugin, config: config}, position} ->
      %Trial{}
      |> Trial.changeset(%{study_id: study_id, position: position, plugin: plugin, config: config})
      |> Repo.insert!()
    end)
  end
end
