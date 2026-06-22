defmodule SochoWeb.UserLive.Show do
  use SochoWeb, :live_view

  alias Socho.Accounts
  alias Socho.Clients

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = Accounts.get_user!(id)
    client = if user.client_id, do: Clients.get_client(user.client_id), else: nil

    {:ok, assign(socket, user: user, client: client)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto p-6 space-y-6">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <.link href="/users" class="btn btn-ghost btn-sm">← Users</.link>
            <h1 class="text-2xl font-bold">{@user.username || @user.email}</h1>
          </div>
          <.link href={"/users/#{@user.id}/edit"} class="btn btn-primary btn-sm">Edit</.link>
        </div>

        <div class="card bg-base-200 shadow p-6 space-y-4">
          <div class="grid grid-cols-2 gap-4">
            <div>
              <p class="text-xs opacity-50 uppercase tracking-wide">Email</p>
              <p class="font-medium">{@user.email}</p>
            </div>
            <div>
              <p class="text-xs opacity-50 uppercase tracking-wide">Display Name</p>
              <p class="font-medium">{@user.username || "—"}</p>
            </div>
            <div>
              <p class="text-xs opacity-50 uppercase tracking-wide">Role</p>
              <span class={["badge badge-sm", role_badge_class(@user.role)]}>
                {String.capitalize(to_string(@user.role))}
              </span>
            </div>
            <div>
              <p class="text-xs opacity-50 uppercase tracking-wide">Status</p>
              <span class={["badge badge-sm", if(@user.confirmed_at, do: "badge-success", else: "badge-ghost")]}>
                {if @user.confirmed_at, do: "Confirmed", else: "Pending"}
              </span>
            </div>
            <div>
              <p class="text-xs opacity-50 uppercase tracking-wide">Client</p>
              <p class="font-medium">
                <%= if @client do %>
                  <.link href={"/clients/#{@client.id}"} class="link link-primary">{@client.name}</.link>
                <% else %>
                  —
                <% end %>
              </p>
            </div>
            <div>
              <p class="text-xs opacity-50 uppercase tracking-wide">Joined</p>
              <p class="font-medium">{Calendar.strftime(@user.inserted_at, "%b %d, %Y")}</p>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp role_badge_class(:admin), do: "badge-error"
  defp role_badge_class(:manager), do: "badge-warning"
  defp role_badge_class(_), do: "badge-neutral"
end
