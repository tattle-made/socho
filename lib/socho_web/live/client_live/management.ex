defmodule SochoWeb.ClientLive.Management do
  use SochoWeb, :live_view

  alias Socho.Accounts
  alias Socho.Accounts.User
  alias Socho.Clients
  alias Socho.Clients.Client

  @impl true
  def mount(_params, _session, socket) do
    client_changeset = Client.changeset(%Client{}, %{})
    invite_changeset = User.invitation_changeset(%User{}, %{})

    {:ok,
     assign(socket,
       client_rows: Clients.client_counts(),
       client_form: to_form(client_changeset, as: "client"),
       invite_form: to_form(invite_changeset, as: "invite"),
       show_client_form: false,
       created_client: nil,
       invite_client_id: nil,
       invite_sent: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-3xl mx-auto p-6 space-y-6">

        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <h1 class="text-2xl font-bold">Clients</h1>
            <span class="badge badge-neutral">{length(@client_rows)}</span>
          </div>
          <button class="btn btn-primary btn-sm" phx-click="toggle_client_form">
            {if @show_client_form, do: "Cancel", else: "+ New Client"}
          </button>
        </div>

        <%!-- Create Client Form --%>
        <div :if={@show_client_form} class="card bg-base-200 shadow p-6">
          <h2 class="text-lg font-semibold mb-4">Create a client</h2>

          <div :if={@created_client} class="alert alert-success mb-4">
            <span>Client <strong>{@created_client}</strong> created.</span>
          </div>

          <.form for={@client_form} id="client_form" phx-submit="create_client" phx-change="validate_client">
            <div class="flex gap-4 items-end">
              <div class="form-control flex-1">
                <label class="label">
                  <span class="label-text">Client name <span class="text-error">*</span></span>
                </label>
                <.input field={@client_form[:name]} type="text" placeholder="e.g. Acme Corp" />
              </div>
              <.button phx-disable-with="Creating..." class="btn btn-primary">
                Create
              </.button>
            </div>
          </.form>
        </div>

        <%!-- Clients Table --%>
        <div class="overflow-x-auto">
          <table class="table table-zebra w-full">
            <thead>
              <tr>
                <th>Name</th>
                <th class="text-right">Participants</th>
                <th class="text-right">Studies</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for {client, participant_count, study_count} <- @client_rows do %>
                <tr>
                  <td class="font-medium">
                    <.link href={"/clients/#{client.id}"} class="link link-hover">{client.name}</.link>
                  </td>
                  <td class="text-right">{participant_count}</td>
                  <td class="text-right">{study_count}</td>
                  <td class="text-right">
                    <button
                      class="btn btn-xs btn-outline"
                      phx-click="open_invite"
                      phx-value-client_id={client.id}
                    >
                      + Invite participant
                    </button>
                  </td>
                </tr>

                <%!-- Inline invite form --%>
                <tr :if={@invite_client_id == client.id}>
                  <td colspan="4" class="bg-base-200 p-4">
                    <div :if={@invite_sent} class="alert alert-success mb-3 py-2 text-sm">
                      <span>Invitation sent to <strong>{@invite_sent}</strong>.</span>
                    </div>

                    <p class="text-sm font-semibold mb-3">
                      Invite participant to <span class="text-primary">{client.name}</span>
                    </p>

                    <.form
                      for={@invite_form}
                      id={"invite_form_#{client.id}"}
                      phx-submit="invite_participant"
                      phx-change="validate_invite"
                      class="flex flex-wrap gap-3 items-end"
                    >
                      <input type="hidden" name="invite[client_id]" value={client.id} />
                      <input type="hidden" name="invite[role]" value="participant" />

                      <div class="form-control">
                        <label class="label py-0.5">
                          <span class="label-text text-xs">Email <span class="text-error">*</span></span>
                        </label>
                        <.input
                          field={@invite_form[:email]}
                          type="email"
                          placeholder="user@example.com"
                          autocomplete="off"
                          spellcheck="false"
                        />
                      </div>

                      <div class="form-control">
                        <label class="label py-0.5">
                          <span class="label-text text-xs">Display name</span>
                        </label>
                        <.input
                          field={@invite_form[:username]}
                          type="text"
                          placeholder="Optional"
                        />
                      </div>

                      <div class="flex gap-2">
                        <.button phx-disable-with="Sending..." class="btn btn-primary btn-sm">
                          Send Invite
                        </.button>
                        <button
                          type="button"
                          class="btn btn-ghost btn-sm"
                          phx-click="close_invite"
                        >
                          Cancel
                        </button>
                      </div>
                    </.form>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <p :if={@client_rows == []} class="text-sm opacity-50 text-center py-6">
            No clients yet. Create one above.
          </p>
        </div>

      </div>
    </Layouts.app>
    """
  end

  # ── Client events ─────────────────────────────────────────────────────────────

  @impl true
  def handle_event("toggle_client_form", _params, socket) do
    {:noreply, assign(socket, show_client_form: !socket.assigns.show_client_form, created_client: nil)}
  end

  def handle_event("validate_client", %{"client" => params}, socket) do
    changeset =
      %Client{}
      |> Client.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, client_form: to_form(changeset, as: "client"))}
  end

  def handle_event("create_client", %{"client" => params}, socket) do
    case Clients.create_client(params) do
      {:ok, client} ->
        fresh = to_form(Client.changeset(%Client{}, %{}), as: "client")

        {:noreply,
         assign(socket,
           client_rows: Clients.client_counts(),
           client_form: fresh,
           created_client: client.name
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, client_form: to_form(changeset, as: "client"))}
    end
  end

  # ── Invite events ─────────────────────────────────────────────────────────────

  def handle_event("open_invite", %{"client_id" => client_id_str}, socket) do
    fresh = to_form(User.invitation_changeset(%User{}, %{}), as: "invite")

    {:noreply,
     assign(socket,
       invite_client_id: String.to_integer(client_id_str),
       invite_form: fresh,
       invite_sent: nil
     )}
  end

  def handle_event("close_invite", _params, socket) do
    {:noreply, assign(socket, invite_client_id: nil, invite_sent: nil)}
  end

  def handle_event("validate_invite", %{"invite" => params}, socket) do
    changeset =
      %User{}
      |> User.invitation_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, invite_form: to_form(changeset, as: "invite"))}
  end

  def handle_event("invite_participant", %{"invite" => params}, socket) do
    url_fun = fn token -> url(~p"/users/log-in/#{token}") end

    case Accounts.invite_user(socket.assigns.current_scope, params, url_fun) do
      {:ok, user} ->
        fresh = to_form(User.invitation_changeset(%User{}, %{}), as: "invite")

        {:noreply,
         assign(socket,
           client_rows: Clients.client_counts(),
           invite_form: fresh,
           invite_sent: user.email
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, invite_form: to_form(changeset, as: "invite"))}
    end
  end
end
