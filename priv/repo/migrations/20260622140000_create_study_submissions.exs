defmodule Socho.Repo.Migrations.CreateStudySubmissions do
  use Ecto.Migration

  def change do
    create table(:study_submissions) do
      add :study_id, references(:studies, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all), null: true
      add :data, :map, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:study_submissions, [:study_id])

    # Prevent the same participant from submitting the same study twice.
    # The partial index only applies when user_id is not null (anonymous
    # submissions are allowed to come in multiple times).
    create unique_index(:study_submissions, [:study_id, :user_id],
             where: "user_id IS NOT NULL",
             name: :study_submissions_user_unique
           )
  end
end
