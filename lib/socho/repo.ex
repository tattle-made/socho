defmodule Socho.Repo do
  use Ecto.Repo,
    otp_app: :socho,
    adapter: Ecto.Adapters.Postgres
end
