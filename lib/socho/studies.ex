defmodule Socho.Studies do
  import Ecto.Query

  alias Socho.Repo
  alias Socho.Studies.{Study, Trial, Submission}

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

  def list_all_studies_for_client(client_id) do
    from(s in Study,
      where: s.client_id == ^client_id,
      order_by: [desc: s.inserted_at]
    )
    |> Repo.all()
  end

  def get_study_meta!(id), do: Repo.get!(Study, id)

  def delete_study(id) do
    case Repo.get(Study, id) do
      nil -> {:error, :not_found}
      study -> Repo.delete(study)
    end
  end

  def update_study(id, attrs) do
    Repo.get!(Study, id)
    |> Study.changeset(attrs)
    |> Repo.update()
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
          extensions: node[:extensions] || %{},
          parent_id: parent_id
        })
        |> Repo.insert!()

      insert_trial_tree(study_id, node[:children] || [], record.id)
    end)
  end

  # ── Import / Export ──────────────────────────────────────────────────────────

  def export_template(study_id) do
    study = get_study!(study_id)

    %{
      "socho_version" => 1,
      "title" => study.title,
      "nodes" => Enum.map(study.trials, &serialize_node/1)
    }
  end

  defp serialize_node(node) do
    %{
      "node_type" => node.node_type,
      "plugin" => node.plugin,
      "config" => node.config || %{},
      "extensions" => node.extensions || %{},
      "children" => Enum.map(node.children || [], &serialize_node/1)
    }
  end

  def import_template(title, client_id, nodes_json) when is_list(nodes_json) do
    nodes = Enum.map(nodes_json, &deserialize_node/1)
    create_study_with_trials(title, client_id, nodes)
  end

  defp deserialize_node(node) when is_map(node) do
    %{
      node_type: node["node_type"] || "trial",
      plugin: node["plugin"],
      config: node["config"] || %{},
      extensions: node["extensions"] || %{},
      children: Enum.map(node["children"] || [], &deserialize_node/1)
    }
  end

  # ── Submissions ──────────────────────────────────────────────────────────────

  def record_submission(study_id, user_id, trial_list) when is_list(trial_list) do
    %Submission{}
    |> Submission.changeset(%{study_id: study_id, user_id: user_id, data: %{"trials" => trial_list}})
    |> Repo.insert()
  end

  def has_submitted?(study_id, user_id) when not is_nil(user_id) do
    Repo.exists?(from s in Submission, where: s.study_id == ^study_id and s.user_id == ^user_id)
  end

  def has_submitted?(_study_id, nil), do: false

  def count_submissions(study_id) do
    Repo.aggregate(from(s in Submission, where: s.study_id == ^study_id), :count)
  end

  def list_submissions(study_id) do
    from(s in Submission, where: s.study_id == ^study_id, order_by: [asc: s.inserted_at])
    |> Repo.all()
  end

  def export_submissions_csv(study_id) do
    submissions = list_submissions(study_id)

    max_trials =
      submissions
      |> Enum.map(fn sub -> length(sub.data["trials"] || []) end)
      |> Enum.max(fn -> 0 end)

    # Build {header, trial_index, key} triples ordered by trial position then key name
    trial_columns =
      if max_trials == 0 do
        []
      else
        Enum.flat_map(0..(max_trials - 1), fn i ->
          keys =
            submissions
            |> Enum.flat_map(fn sub ->
              case Enum.at(sub.data["trials"] || [], i) do
                nil -> []
                trial -> Map.keys(trial)
              end
            end)
            |> Enum.uniq()
            |> Enum.sort()

          Enum.map(keys, fn k -> {"trial_#{i + 1}_#{k}", i, k} end)
        end)
      end

    headers = ["submission_id", "submitted_at"] ++ Enum.map(trial_columns, &elem(&1, 0))

    rows =
      Enum.map(submissions, fn sub ->
        trials = sub.data["trials"] || []

        trial_values =
          Enum.map(trial_columns, fn {_col, i, key} ->
            case Enum.at(trials, i) do
              nil -> ""
              trial -> csv_cell(trial[key])
            end
          end)

        [to_string(sub.id), Calendar.strftime(sub.inserted_at, "%Y-%m-%dT%H:%M:%S")] ++
          trial_values
      end)

    [headers | rows]
    |> Enum.map_join("\n", fn row -> Enum.map_join(row, ",", &csv_escape/1) end)
  end

  defp csv_cell(nil), do: ""
  defp csv_cell(v) when is_binary(v), do: v
  defp csv_cell(v) when is_list(v) or is_map(v), do: Jason.encode!(v)
  defp csv_cell(v), do: to_string(v)

  defp csv_escape(value) do
    str = to_string(value)
    if String.contains?(str, [",", "\"", "\n"]) do
      "\"" <> String.replace(str, "\"", "\"\"") <> "\""
    else
      str
    end
  end
end
