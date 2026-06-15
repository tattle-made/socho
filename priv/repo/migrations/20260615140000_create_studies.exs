defmodule Socho.Repo.Migrations.CreateStudies do
  use Ecto.Migration

  def change do
    create table(:studies) do
      add :title, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "draft"

      timestamps(type: :utc_datetime)
    end
  end
end
