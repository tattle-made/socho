defmodule Socho.AppSettings do
  alias Socho.Repo
  alias Socho.AppSettings.AppSettings

  @singleton_id 1

  def get do
    Repo.get(AppSettings, @singleton_id) || %AppSettings{}
  end

  def get_branding do
    get().branding || %{}
  end

  def update_branding(branding_attrs) do
    result =
      case Repo.get(AppSettings, @singleton_id) do
        nil ->
          %AppSettings{}
          |> AppSettings.branding_changeset(%{branding: branding_attrs})
          |> Repo.insert()

        existing ->
          existing
          |> AppSettings.branding_changeset(%{branding: branding_attrs})
          |> Repo.update()
      end

    case result do
      {:ok, record} ->
        Socho.Cache.put(:branding, record.branding)
        {:ok, record}

      error ->
        error
    end
  end
end
