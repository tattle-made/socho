defmodule SochoWeb.UserLive.Management do
  use SochoWeb, :live_view

  alias Socho.Accounts
  alias Socho.Accounts.User
  alias Socho.Clients

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    assignable_roles = Accounts.assignable_roles(user.role)
    changeset = User.invitation_changeset(%User{}, %{})

    socket =
      socket
      |> assign(:users, list_users_with_clients())
      |> assign(:form, to_form(changeset, as: "invite"))
      |> assign(:assignable_roles, assignable_roles)
      |> assign(:clients, Clients.list_clients())
      |> assign(:invite_sent, nil)
      |> assign(:show_invite_form, false)
      |> assign(:invite_role, nil)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto p-6 space-y-6">

        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <h1 class="text-2xl font-bold">Users</h1>
            <span class="badge badge-neutral">{length(@users)}</span>
          </div>
          <button
            :if={@assignable_roles != []}
            class="btn btn-primary btn-sm"
            phx-click="toggle_invite_form"
          >
            {if @show_invite_form, do: "Cancel", else: "+ Invite User"}
          </button>
        </div>

        <%!-- Invite User Form --%>
        <div :if={@show_invite_form && @assignable_roles != []} class="card bg-base-200 shadow p-6">
          <h2 class="text-lg font-semibold mb-4">Invite a new user</h2>

          <div :if={@invite_sent} class="alert alert-success mb-4">
            <span>Invitation sent to <strong>{@invite_sent}</strong>.</span>
          </div>

          <.form for={@form} id="invite_form" phx-submit="invite" phx-change="validate">
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Email <span class="text-error">*</span></span>
                </label>
                <.input
                  field={@form[:email]}
                  type="email"
                  placeholder="user@example.com"
                  autocomplete="off"
                  spellcheck="false"
                />
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Display name</span>
                </label>
                <.input
                  field={@form[:username]}
                  type="text"
                  placeholder="Optional display name"
                />
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Role <span class="text-error">*</span></span>
                </label>
                <.input
                  field={@form[:role]}
                  type="select"
                  options={Enum.map(@assignable_roles, &{String.capitalize(to_string(&1)), &1})}
                  phx-change="role_changed"
                />
              </div>

              <div :if={@invite_role == "participant"} class="form-control">
                <label class="label">
                  <span class="label-text">Client <span class="text-error">*</span></span>
                </label>
                <.input
                  field={@form[:client_id]}
                  type="select"
                  prompt="Select a client"
                  options={Enum.map(@clients, &{&1.name, &1.id})}
                />
              </div>
            </div>

            <div class="mt-4">
              <.button phx-disable-with="Sending..." class="btn btn-primary">
                Send Invitation
              </.button>
            </div>
          </.form>
        </div>

        <%!-- Users Table --%>
        <div class="overflow-x-auto">
          <table class="table table-zebra w-full">
            <thead>
              <tr>
                <th>Display Name</th>
                <th>Email</th>
                <th>Role</th>
                <th>Client</th>
                <th>Status</th>
                <th>Joined</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={u <- @users}>
                <td class="font-medium">
                  {u.username || "—"}
                </td>
                <td class="text-sm opacity-80">{u.email}</td>
                <td>
                  <span class={["badge badge-sm", role_badge_class(u.role)]}>
                    {String.capitalize(to_string(u.role))}
                  </span>
                </td>
                <td class="text-sm opacity-70">
                  {if u.role == :participant and u.client, do: u.client.name, else: "—"}
                </td>
                <td>
                  <span class={["badge badge-sm", status_badge_class(u.confirmed_at)]}>
                    {if u.confirmed_at, do: "Confirmed", else: "Pending"}
                  </span>
                </td>
                <td class="text-sm opacity-60">
                  {Calendar.strftime(u.inserted_at, "%b %d, %Y")}
                </td>
              </tr>
            </tbody>
          </table>
          <p :if={@users == []} class="text-sm opacity-50 text-center py-6">No users yet.</p>
        </div>

      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("toggle_invite_form", _params, socket) do
    {:noreply, assign(socket, show_invite_form: !socket.assigns.show_invite_form, invite_sent: nil)}
  end

  def handle_event("role_changed", %{"invite" => %{"role" => role}}, socket) do
    {:noreply, assign(socket, invite_role: role)}
  end

  def handle_event("validate", %{"invite" => params}, socket) do
    changeset =
      %User{}
      |> User.invitation_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: "invite"), invite_role: params["role"])}
  end

  def handle_event("invite", %{"invite" => params}, socket) do
    inviter_scope = socket.assigns.current_scope

    url_fun = fn token -> url(~p"/users/log-in/#{token}") end

    case Accounts.invite_user(inviter_scope, params, url_fun) do
      {:ok, user} ->
        fresh_changeset = User.invitation_changeset(%User{}, %{})

        socket =
          socket
          |> assign(:users, list_users_with_clients())
          |> assign(:form, to_form(fresh_changeset, as: "invite"))
          |> assign(:invite_sent, user.email)
          |> assign(:invite_role, nil)

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "invite"))}
    end
  end

  defp list_users_with_clients do
    Accounts.list_users() |> Socho.Repo.preload(:client)
  end

  defp role_badge_class(:admin), do: "badge-error"
  defp role_badge_class(:manager), do: "badge-warning"
  defp role_badge_class(_), do: "badge-neutral"

  defp status_badge_class(nil), do: "badge-ghost"
  defp status_badge_class(_confirmed_at), do: "badge-success"
end
