defmodule SochoWeb.StudyLive.Index do
  use SochoWeb, :live_view

  alias Socho.Studies

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, studies: Studies.list_studies())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto p-6 space-y-6">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Studies</h1>
        <.link href="/studies/new" class="btn btn-primary btn-sm">+ New Study</.link>
      </div>

      <p :if={@studies == []} class="text-sm opacity-50">No studies yet.</p>

      <div class="space-y-2">
        <%= for study <- @studies do %>
          <div class="card bg-base-200 shadow p-4 flex flex-row items-center justify-between">
            <div class="space-y-1">
              <div class="font-semibold">{study.title}</div>
              <div class="flex gap-2 text-xs opacity-60">
                <span class="badge badge-sm">{study.status}</span>
                <span>#{study.id}</span>
              </div>
            </div>
            <div class="flex gap-2">
              <.link href={"/studies/#{study.id}/edit"} class="btn btn-sm btn-outline">
                Edit
              </.link>
              <.link href={"/study/#{study.id}"} class="btn btn-sm btn-ghost" target="_blank">
                Preview
              </.link>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
