defmodule Socho.Studies do
  import Ecto.Query

  alias Socho.Repo
  alias Socho.Studies.{Study, Trial}

  def list_studies do
    from(s in Study, order_by: [desc: s.inserted_at])
    |> Repo.all()
    |> Repo.preload(:client)
  end

  def list_studies_for_client(client_id) do
    from(s in Study,
      where: s.client_id == ^client_id and s.status == :published,
      order_by: [desc: s.inserted_at]
    )
    |> Repo.all()
  end

  def get_study!(id) do
    study = Repo.get!(Study, id)
    trials_flat = Repo.all(from t in Trial, where: t.study_id == ^id, order_by: t.position)
    %{study | trials: build_trial_tree(trials_flat)}
  end

  def create_study_with_trials(title, client_id, nodes) do
    Repo.transaction(fn ->
      study =
        %Study{}
        |> Study.changeset(%{title: title, status: :draft, client_id: client_id})
        |> Repo.insert!()

      insert_trial_tree(study.id, nodes)
      get_study!(study.id)
    end)
  end

  def update_study_with_trials(id, title, client_id, nodes) do
    Repo.transaction(fn ->
      study = Repo.get!(Study, id)

      study
      |> Study.changeset(%{title: title, client_id: client_id})
      |> Repo.update!()

      Repo.delete_all(from(t in Trial, where: t.study_id == ^id))
      insert_trial_tree(id, nodes)
      get_study!(id)
    end)
  end

  defp build_trial_tree(flat) do
    by_parent = Enum.group_by(flat, & &1.parent_id)
    build_children(nil, by_parent)
  end

  defp build_children(parent_id, by_parent) do
    (by_parent[parent_id] || [])
    |> Enum.map(fn node ->
      %{node | children: build_children(node.id, by_parent)}
    end)
  end

  defp insert_trial_tree(study_id, nodes, parent_id \\ nil) do
    nodes
    |> Enum.with_index(1)
    |> Enum.each(fn {node, pos} ->
      record =
        %Trial{}
        |> Trial.changeset(%{
          study_id: study_id,
          position: pos,
          node_type: node[:node_type] || "trial",
          plugin: node[:plugin],
          config: node[:config] || %{},
          parent_id: parent_id
        })
        |> Repo.insert!()

      insert_trial_tree(study_id, node[:children] || [], record.id)
    end)
  end
end
