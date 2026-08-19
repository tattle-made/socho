defmodule Socho.Cache do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{branding: Socho.AppSettings.get_branding()} end, name: __MODULE__)
  end

  def get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end

  def put(key, value) do
    Agent.update(__MODULE__, &Map.put(&1, key, value))
  end
end
