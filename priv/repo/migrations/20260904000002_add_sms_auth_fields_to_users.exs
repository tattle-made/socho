defmodule Socho.Repo.Migrations.AddSmsAuthFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :email, :citext, null: true
      add :phone_number, :string, null: true
      add :verification_method, :string, null: false, default: "email"
    end

    create unique_index(:users, [:phone_number], where: "phone_number IS NOT NULL")
  end
end
