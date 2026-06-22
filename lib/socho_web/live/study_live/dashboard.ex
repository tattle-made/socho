defmodule SochoWeb.StudyLive.Dashboard do
  use SochoWeb, :live_view

  alias Socho.Studies

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    client = socket.assigns.current_scope.client

    studies =
      if user.client_id,
        do: Studies.list_studies_for_client(user.client_id),
        else: []

    {:ok, assign(socket, studies: studies, client: client)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-3xl mx-auto p-6 space-y-6">

        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold">My Studies</h1>
            <p :if={@client} class="text-sm opacity-60 mt-0.5">{@client.name}</p>
            <p :if={!@client} class="text-sm text-warning mt-0.5">
              Your account is not assigned to a client. Contact an administrator.
            </p>
          </div>
        </div>

        <p :if={@studies == []} class="text-sm opacity-50">
          No published studies are available for your organisation yet.
        </p>

        <div class="grid gap-4 sm:grid-cols-2">
          <%= for study <- @studies do %>
            <div class="card bg-base-200 shadow p-5 space-y-3">
              <h2 class="font-semibold text-lg leading-tight">{study.title}</h2>
              <p :if={study.description} class="text-sm opacity-60">{study.description}</p>
              <.link
                href={"/study/#{study.id}"}
                class="btn btn-primary btn-sm w-full"
              >
                Start Study
              </.link>
            </div>
          <% end %>
        </div>

      </div>
    </Layouts.app>
    """
  end
end
