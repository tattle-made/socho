defmodule Socho.Repo.Migrations.CreateTrials do
  use Ecto.Migration

  def change do
    create table(:trials) do
      add :study_id, references(:studies, on_delete: :delete_all), null: false
      add :position, :integer, null: false
      add :plugin, :string, null: false
      add :config, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:trials, [:study_id])
    create index(:trials, [:study_id, :position])
  end
end
