defmodule SochoWeb.UserLive.Edit do
  use SochoWeb, :live_view

  alias Socho.Accounts
  alias Socho.Accounts.User
  alias Socho.Clients

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = Accounts.get_user!(id)
    changeset = User.profile_changeset(user, %{})
    clients = Clients.list_clients()

    {:ok,
     assign(socket,
       user: user,
       form: to_form(changeset, as: "user"),
       clients: clients
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto p-6 space-y-6">
        <div class="flex items-center gap-3">
          <.link href={"/users/#{@user.id}"} class="btn btn-ghost btn-sm">← Back</.link>
          <h1 class="text-2xl font-bold">Edit User</h1>
        </div>

        <div class="card bg-base-200 shadow p-6">
          <p class="text-sm opacity-60 mb-4">{@user.email}</p>

          <.form for={@form} id="user_edit_form" phx-submit="save" phx-change="validate">
            <div class="space-y-4">
              <div class="form-control">
                <label class="label"><span class="label-text">Display name</span></label>
                <.input field={@form[:username]} type="text" placeholder="Optional" />
              </div>

              <div class="form-control">
                <label class="label"><span class="label-text">Role</span></label>
                <.input
                  field={@form[:role]}
                  type="select"
                  options={Enum.map([:admin, :manager, :participant], &{String.capitalize(to_string(&1)), &1})}
                />
              </div>

              <div class="form-control">
                <label class="label"><span class="label-text">Client</span></label>
                <.input
                  field={@form[:client_id]}
                  type="select"
                  options={[{"None", ""}] ++ Enum.map(@clients, &{&1.name, &1.id})}
                />
              </div>
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
  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      socket.assigns.user
      |> User.profile_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: "user"))}
  end

  def handle_event("save", %{"user" => params}, socket) do
    params = Map.update(params, "client_id", nil, fn
      "" -> nil
      v  -> v
    end)

    case Accounts.update_user_profile(socket.assigns.user, params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User updated.")
         |> push_navigate(to: "/users/#{user.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "user"))}
    end
  end
end
