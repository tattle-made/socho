defmodule SochoWeb.UserLive.Management do
  use SochoWeb, :live_view

  alias Socho.Accounts
  alias Socho.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    assignable_roles = Accounts.assignable_roles(user.role)
    changeset = User.invitation_changeset(%User{}, %{})

    {:ok,
     assign(socket,
       users: list_staff_and_unaffiliated(),
       form: to_form(changeset, as: "invite"),
       assignable_roles: assignable_roles,
       invite_sent: nil,
       show_invite_form: false
     )}
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
          <div class="flex gap-2">
            <.link href="/clients" class="btn btn-outline btn-sm">
              Client Users →
            </.link>
            <button
              :if={@assignable_roles != []}
              class="btn btn-primary btn-sm"
              phx-click="toggle_invite_form"
            >
              {if @show_invite_form, do: "Cancel", else: "+ Invite User"}
            </button>
          </div>
        </div>

        <%!-- Invite Form --%>
        <div :if={@show_invite_form && @assignable_roles != []} class="card bg-base-200 shadow p-6">
          <h2 class="text-lg font-semibold mb-4">Invite a new user</h2>

          <div :if={@invite_sent} class="alert alert-success mb-4">
            <span>Invitation sent to <strong>{@invite_sent}</strong>.</span>
          </div>

          <.form for={@form} id="invite_form" phx-submit="invite" phx-change="validate">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
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
                <.input field={@form[:username]} type="text" placeholder="Optional" />
              </div>

              <div class="form-control">
                <label class="label">
                  <span class="label-text">Role <span class="text-error">*</span></span>
                </label>
                <.input
                  field={@form[:role]}
                  type="select"
                  options={Enum.map(@assignable_roles, &{String.capitalize(to_string(&1)), &1})}
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

        <%!-- Users table --%>
        <div class="overflow-x-auto">
          <table class="table table-zebra w-full">
            <thead>
              <tr>
                <th>Display Name</th>
                <th>Email</th>
                <th>Role</th>
                <th>Status</th>
                <th>Joined</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={u <- @users}>
                <td class="font-medium">{u.username || "—"}</td>
                <td class="text-sm opacity-80">{u.email}</td>
                <td>
                  <span class={["badge badge-sm", role_badge_class(u.role)]}>
                    {String.capitalize(to_string(u.role))}
                  </span>
                </td>
                <td>
                  <span class={["badge badge-sm", status_badge_class(u.confirmed_at)]}>
                    {if u.confirmed_at, do: "Confirmed", else: "Pending"}
                  </span>
                </td>
                <td class="text-sm opacity-60">
                  {Calendar.strftime(u.inserted_at, "%b %d, %Y")}
                </td>
                <td>
                  <.link href={"/users/#{u.id}"} class="btn btn-xs btn-ghost">View</.link>
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

  def handle_event("validate", %{"invite" => params}, socket) do
    changeset =
      %User{}
      |> User.invitation_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: "invite"))}
  end

  def handle_event("invite", %{"invite" => params}, socket) do
    url_fun = fn token -> url(~p"/users/log-in/#{token}") end

    case Accounts.invite_user(socket.assigns.current_scope, params, url_fun) do
      {:ok, user} ->
        fresh_changeset = User.invitation_changeset(%User{}, %{})

        {:noreply,
         assign(socket,
           users: list_staff_and_unaffiliated(),
           form: to_form(fresh_changeset, as: "invite"),
           invite_sent: user.email
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "invite"))}
    end
  end

  defp list_staff_and_unaffiliated do
    import Ecto.Query
    Socho.Repo.all(
      from u in User,
      where: u.role in [:admin, :manager] or (u.role == :participant and is_nil(u.client_id)),
      order_by: [asc: u.role, asc: u.inserted_at]
    )
  end

  defp role_badge_class(:admin), do: "badge-error"
  defp role_badge_class(:manager), do: "badge-warning"
  defp role_badge_class(_), do: "badge-neutral"

  defp status_badge_class(nil), do: "badge-ghost"
  defp status_badge_class(_confirmed_at), do: "badge-success"
end
