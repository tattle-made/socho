defmodule SochoWeb.ClientLive.Management do
  use SochoWeb, :live_view

  alias Socho.Clients
  alias Socho.Clients.Client

  @impl true
  def mount(_params, _session, socket) do
    changeset = Client.changeset(%Client{}, %{})

    {:ok,
     assign(socket,
       client_rows: Clients.client_counts(),
       form: to_form(changeset, as: "client"),
       show_form: false,
       created: nil
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
          <button class="btn btn-primary btn-sm" phx-click="toggle_form">
            {if @show_form, do: "Cancel", else: "+ New Client"}
          </button>
        </div>

        <%!-- Create Client Form --%>
        <div :if={@show_form} class="card bg-base-200 shadow p-6">
          <h2 class="text-lg font-semibold mb-4">Create a client</h2>

          <div :if={@created} class="alert alert-success mb-4">
            <span>Client <strong>{@created}</strong> created.</span>
          </div>

          <.form for={@form} id="client_form" phx-submit="create" phx-change="validate">
            <div class="flex gap-4 items-end">
              <div class="form-control flex-1">
                <label class="label">
                  <span class="label-text">Client name <span class="text-error">*</span></span>
                </label>
                <.input field={@form[:name]} type="text" placeholder="e.g. Acme Corp" />
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
              </tr>
            </thead>
            <tbody>
              <tr :for={{client, participant_count, study_count} <- @client_rows}>
                <td class="font-medium">{client.name}</td>
                <td class="text-right">{participant_count}</td>
                <td class="text-right">{study_count}</td>
              </tr>
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

  @impl true
  def handle_event("toggle_form", _params, socket) do
    {:noreply, assign(socket, show_form: !socket.assigns.show_form, created: nil)}
  end

  def handle_event("validate", %{"client" => params}, socket) do
    changeset =
      %Client{}
      |> Client.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: "client"))}
  end

  def handle_event("create", %{"client" => params}, socket) do
    case Clients.create_client(params) do
      {:ok, client} ->
        fresh = Client.changeset(%Client{}, %{})

        {:noreply,
         assign(socket,
           client_rows: Clients.client_counts(),
           form: to_form(fresh, as: "client"),
           created: client.name
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "client"))}
    end
  end
end
