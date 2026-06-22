defmodule Socho.Studies.Submission do
  use Ecto.Schema
  import Ecto.Changeset

  schema "study_submissions" do
    field :data, :map

    belongs_to :study, Socho.Studies.Study
    belongs_to :user, Socho.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(submission, attrs) do
    submission
    |> cast(attrs, [:study_id, :user_id, :data])
    |> validate_required([:study_id, :data])
    |> unique_constraint([:study_id, :user_id], name: :study_submissions_user_unique)
  end
end
