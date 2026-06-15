defmodule Socho.Accounts.UserAdmin do
  @moduledoc """
  Helper functions for provisioning users with explicit roles.
  Intended for use in seeds, mix tasks, and admin tooling.
  """

  alias Socho.Accounts.User
  alias Socho.Repo

  @doc """
  Creates a user with the given email, password, and role.

  Role must be one of: `:admin`, `:manager`, `:participant`.

  Returns `{:ok, user}` or `{:error, changeset}`.

  ## Example

      iex> UserAdmin.create_user("alice@example.com", "strongpassword123", :admin)
      {:ok, %User{}}
  """
  def create_user(email, password, role) do
    %User{}
    |> User.admin_registration_changeset(%{email: email, password: password, role: role})
    |> Repo.insert()
  end
end
