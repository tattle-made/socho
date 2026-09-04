defmodule Socho.Repo.Migrations.AddRemoteIpToStudySubmissions do
  use Ecto.Migration

  def change do
    alter table(:study_submissions) do
      add :remote_ip, :string
    end
  end
end
