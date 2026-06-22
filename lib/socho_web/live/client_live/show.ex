defmodule SochoWeb.ClientLive.Show do
  use SochoWeb, :live_view

  alias Socho.Clients
  alias Socho.Accounts
  alias Socho.Studies

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    client = Clients.get_client!(id)
    users = Accounts.list_users_for_client(id)
    studies = Studies.list_all_studies_for_client(id)

    {:ok, assign(socket, client: client, users: users, studies: studies)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto p-6 space-y-6">

        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <.link href="/clients" class="btn btn-ghost btn-sm">← Clients</.link>
            <h1 class="text-2xl font-bold">{@client.name}</h1>
          </div>
          <.link href={"/clients/#{@client.id}/edit"} class="btn btn-primary btn-sm">Edit</.link>
        </div>

        <%!-- Participants --%>
        <div>
          <h2 class="text-lg font-semibold mb-3">
            Participants
            <span class="badge badge-neutral badge-sm ml-1">{length(@users)}</span>
          </h2>
          <div class="overflow-x-auto">
            <table class="table table-zebra w-full">
              <thead>
                <tr>
                  <th>Display Name</th>
                  <th>Email</th>
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
                    <span class={["badge badge-sm", if(u.confirmed_at, do: "badge-success", else: "badge-ghost")]}>
                      {if u.confirmed_at, do: "Confirmed", else: "Pending"}
                    </span>
                  </td>
                  <td class="text-sm opacity-60">{Calendar.strftime(u.inserted_at, "%b %d, %Y")}</td>
                  <td>
                    <.link href={"/users/#{u.id}"} class="btn btn-xs btn-ghost">View</.link>
                  </td>
                </tr>
              </tbody>
            </table>
            <p :if={@users == []} class="text-sm opacity-50 text-center py-6">No participants yet.</p>
          </div>
        </div>

        <%!-- Studies --%>
        <div>
          <h2 class="text-lg font-semibold mb-3">
            Studies
            <span class="badge badge-neutral badge-sm ml-1">{length(@studies)}</span>
          </h2>
          <div class="overflow-x-auto">
            <table class="table table-zebra w-full">
              <thead>
                <tr>
                  <th>Title</th>
                  <th>Status</th>
                  <th>Created</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={s <- @studies}>
                  <td class="font-medium">{s.title}</td>
                  <td>
                    <span class={["badge badge-sm", if(s.status == :published, do: "badge-success", else: "badge-ghost")]}>
                      {String.capitalize(to_string(s.status))}
                    </span>
                  </td>
                  <td class="text-sm opacity-60">{Calendar.strftime(s.inserted_at, "%b %d, %Y")}</td>
                  <td>
                    <.link href={"/studies/#{s.id}/edit"} class="btn btn-xs btn-ghost">Edit</.link>
                  </td>
                </tr>
              </tbody>
            </table>
            <p :if={@studies == []} class="text-sm opacity-50 text-center py-6">No studies yet.</p>
          </div>
        </div>

      </div>
    </Layouts.app>
    """
  end
end
