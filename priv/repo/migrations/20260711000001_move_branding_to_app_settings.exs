defmodule Socho.Repo.Migrations.MoveBrandingToAppSettings do
  use Ecto.Migration

  def change do
    alter table(:clients) do
      remove :branding, :map, default: %{}
    end

    create table(:app_settings) do
      add :branding, :map, default: %{}
      timestamps(type: :utc_datetime)
    end
  end
end
