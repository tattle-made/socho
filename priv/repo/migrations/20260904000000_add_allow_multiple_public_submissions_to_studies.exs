defmodule Socho.Repo.Migrations.AddAllowMultiplePublicSubmissionsToStudies do
  use Ecto.Migration

  def change do
    alter table(:studies) do
      add :allow_multiple_public_submissions, :boolean, default: true, null: false
    end
  end
end
