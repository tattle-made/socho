defmodule Socho.Repo.Migrations.AddExtensionsToTrials do
  use Ecto.Migration

  def change do
    alter table(:trials) do
      add :extensions, :map, default: %{}
    end
  end
end
