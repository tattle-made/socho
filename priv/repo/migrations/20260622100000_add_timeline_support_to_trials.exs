defmodule Socho.Repo.Migrations.AddTimelineSupportToTrials do
  use Ecto.Migration

  def change do
    alter table(:trials) do
      add :node_type, :string, null: false, default: "trial"
      add :parent_id, references(:trials, on_delete: :delete_all), null: true
      modify :plugin, :string, null: true
    end

    create index(:trials, [:parent_id])
  end
end
