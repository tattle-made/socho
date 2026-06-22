defmodule Socho.Repo.Migrations.AddClientIdToStudies do
  use Ecto.Migration

  def change do
    alter table(:studies) do
      add :client_id, references(:clients, on_delete: :nilify_all), null: true
    end

    create index(:studies, [:client_id])
  end
end
