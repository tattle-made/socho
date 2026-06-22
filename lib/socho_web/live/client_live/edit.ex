defmodule SochoWeb.ClientLive.Edit do
  use SochoWeb, :live_view

  alias Socho.Clients
  alias Socho.Clients.Client

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    client = Clients.get_client!(id)
    changeset = Client.changeset(client, %{})

    {:ok, assign(socket, client: client, form: to_form(changeset, as: "client"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-xl mx-auto p-6 space-y-6">
        <div class="flex items-center gap-3">
          <.link href={"/clients/#{@client.id}"} class="btn btn-ghost btn-sm">← Back</.link>
          <h1 class="text-2xl font-bold">Edit Client</h1>
        </div>

        <div class="card bg-base-200 shadow p-6">
          <.form for={@form} id="client_edit_form" phx-submit="save" phx-change="validate">
            <div class="form-control">
              <label class="label"><span class="label-text">Client name <span class="text-error">*</span></span></label>
              <.input field={@form[:name]} type="text" placeholder="e.g. Acme Corp" />
            </div>

            <div class="mt-6">
              <.button phx-disable-with="Saving..." class="btn btn-primary">Save Changes</.button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"client" => params}, socket) do
    changeset =
      socket.assigns.client
      |> Client.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: "client"))}
  end

  def handle_event("save", %{"client" => params}, socket) do
    case Clients.update_client(socket.assigns.client, params) do
      {:ok, client} ->
        {:noreply,
         socket
         |> put_flash(:info, "Client updated.")
         |> push_navigate(to: "/clients/#{client.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "client"))}
    end
  end
end
