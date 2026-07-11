defmodule Socho.AppSettings.AppSettings do
  use Ecto.Schema
  import Ecto.Changeset

  schema "app_settings" do
    field :branding, :map, default: %{}
    timestamps(type: :utc_datetime)
  end

  def branding_changeset(settings, attrs) do
    settings
    |> cast(attrs, [:branding])
    |> validate_branding()
  end

  defp validate_branding(changeset) do
    case get_change(changeset, :branding) do
      nil -> changeset
      branding ->
        logo_url = branding["logo_url"]
        if logo_url && logo_url != "" && not String.starts_with?(logo_url, ["http://", "https://"]) do
          add_error(changeset, :branding, "logo URL must start with http:// or https://")
        else
          changeset
        end
    end
  end
end
