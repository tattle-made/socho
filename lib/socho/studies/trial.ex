defmodule Socho.Studies.Trial do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trials" do
    field :position, :integer
    field :plugin, :string
    field :config, :map, default: %{}

    belongs_to :study, Socho.Studies.Study

    timestamps(type: :utc_datetime)
  end

  def changeset(trial, attrs) do
    trial
    |> cast(attrs, [:position, :plugin, :config, :study_id])
    |> validate_required([:position, :plugin, :study_id])
  end
end
