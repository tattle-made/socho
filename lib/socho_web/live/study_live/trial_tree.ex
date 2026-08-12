defmodule SochoWeb.StudyLive.TrialTree do
  @moduledoc false

  def stamp_ids(nodes) do
    Enum.map(nodes, fn node ->
      node
      |> Map.put(:id, System.unique_integer([:positive]))
      |> Map.update(:children, [], &stamp_ids/1)
    end)
  end

  def db_trial_to_node(trial) do
    %{
      id: System.unique_integer([:positive]),
      node_type: trial.node_type,
      plugin: trial.plugin,
      config: trial.config,
      extensions: trial.extensions || %{},
      children: Enum.map(trial.children, &db_trial_to_node/1)
    }
  end

  def node_to_map(node) do
    %{
      node_type: node.node_type,
      plugin: node.plugin,
      config: node.config,
      extensions: node.extensions || %{},
      children: Enum.map(node.children || [], &node_to_map/1)
    }
  end

  def find_node(_nodes, nil), do: nil

  def find_node(nodes, id) do
    Enum.find_value(nodes, fn node ->
      if node.id == id, do: node, else: find_node(node.children, id)
    end)
  end

  def update_node_config(nodes, id, new_config) do
    Enum.map(nodes, fn node ->
      if node.id == id do
        %{node | config: new_config}
      else
        %{node | children: update_node_config(node.children, id, new_config)}
      end
    end)
  end

  def update_node_children(nodes, id, new_children) do
    Enum.map(nodes, fn node ->
      if node.id == id do
        %{node | children: new_children}
      else
        %{node | children: update_node_children(node.children, id, new_children)}
      end
    end)
  end

  def update_node_extensions(nodes, id, new_extensions) do
    Enum.map(nodes, fn node ->
      if node.id == id do
        %{node | extensions: new_extensions}
      else
        %{node | children: update_node_extensions(node.children, id, new_extensions)}
      end
    end)
  end

  def remove_node_from_tree(nodes, id) do
    nodes
    |> Enum.reject(&(&1.id == id))
    |> Enum.map(fn node -> %{node | children: remove_node_from_tree(node.children, id)} end)
  end

  def add_child_to_node(nodes, parent_id, new_node) do
    Enum.map(nodes, fn node ->
      if node.id == parent_id do
        %{node | children: node.children ++ [new_node]}
      else
        %{node | children: add_child_to_node(node.children, parent_id, new_node)}
      end
    end)
  end

  def move_node_in_tree(nodes, id, direction) do
    idx = Enum.find_index(nodes, &(&1.id == id))

    if idx != nil do
      do_move(nodes, idx, direction)
    else
      Enum.map(nodes, fn node ->
        %{node | children: move_node_in_tree(node.children, id, direction)}
      end)
    end
  end

  defp do_move(nodes, 0, :up), do: nodes
  defp do_move(nodes, idx, :down) when idx == length(nodes) - 1, do: nodes
  defp do_move(nodes, idx, :up), do: swap(nodes, idx - 1, idx)
  defp do_move(nodes, idx, :down), do: swap(nodes, idx, idx + 1)

  defp swap(list, i, j) do
    a = Enum.at(list, i)
    b = Enum.at(list, j)
    list |> List.replace_at(i, b) |> List.replace_at(j, a)
  end
end
