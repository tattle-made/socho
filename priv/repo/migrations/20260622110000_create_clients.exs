defmodule Socho.Repo.Migrations.CreateClients do
  use Ecto.Migration

  def change do
    create table(:clients) do
      add :name, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:clients, [:name])
  end
end
