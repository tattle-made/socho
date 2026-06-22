defmodule Socho.Studies.Study do
  use Ecto.Schema
  import Ecto.Changeset

  schema "studies" do
    field :title, :string
    field :description, :string
    field :status, Ecto.Enum, values: [:draft, :published], default: :draft
    field :client_id, :id

    belongs_to :client, Socho.Clients.Client, define_field: false
    has_many :trials, Socho.Studies.Trial, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  def changeset(study, attrs) do
    study
    |> cast(attrs, [:title, :description, :status, :client_id])
    |> validate_required([:title])
    |> validate_length(:title, min: 1, max: 255)
  end
end
