defmodule Socho.Studies.Study do
  use Ecto.Schema
  import Ecto.Changeset

  schema "studies" do
    field :title, :string
    field :description, :string
    field :status, Ecto.Enum, values: [:draft, :published], default: :draft

    has_many :trials, Socho.Studies.Trial, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  def changeset(study, attrs) do
    study
    |> cast(attrs, [:title, :description, :status])
    |> validate_required([:title])
    |> validate_length(:title, min: 1, max: 255)
  end
end
