defmodule Socho.Repo.Migrations.AddBrandingToClients do
  use Ecto.Migration

  def change do
    alter table(:clients) do
      add :branding, :map, default: %{}
    end
  end
end
