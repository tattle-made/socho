defmodule Socho.Studies.Trial do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trials" do
    field :position, :integer
    field :plugin, :string
    field :config, :map, default: %{}
    field :extensions, :map, default: %{}
    field :node_type, :string, default: "trial"
    field :parent_id, :integer
    field :children, :any, virtual: true, default: []

    belongs_to :study, Socho.Studies.Study
    belongs_to :parent, __MODULE__, foreign_key: :parent_id, define_field: false
    has_many :child_trials, __MODULE__, foreign_key: :parent_id

    timestamps(type: :utc_datetime)
  end

  def changeset(trial, attrs) do
    trial
    |> cast(attrs, [:position, :plugin, :config, :extensions, :study_id, :node_type, :parent_id])
    |> validate_required([:position, :study_id, :node_type])
    |> validate_inclusion(:node_type, ["trial", "timeline"])
  end
end
