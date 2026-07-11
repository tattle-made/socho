defmodule SochoWeb.StudyLive.Index do
  use SochoWeb, :live_view

  alias Socho.Studies

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, studies: Studies.list_studies())}
  end

  @impl true
  def handle_event("delete_study", %{"id" => id}, socket) do
    role = socket.assigns.current_scope.user.role

    if role in [:admin, :manager] do
      case Studies.delete_study(String.to_integer(id)) do
        {:ok, _} ->
          {:noreply, assign(socket, studies: Studies.list_studies())}

        {:error, :not_found} ->
          {:noreply, put_flash(socket, :error, "Study not found.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete study.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You are not authorized to delete studies.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
    <div class="max-w-3xl mx-auto p-6 space-y-6">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Studies</h1>
        <div class="flex items-center gap-2">
          <details class="relative">
            <summary class="btn btn-outline btn-sm list-none cursor-pointer">↑ Import</summary>
            <div class="absolute right-0 top-full mt-2 z-10 bg-base-100 border border-base-300 rounded-lg shadow-lg p-4 w-72">
              <p class="text-sm font-medium mb-2">Import study template</p>
              <p class="text-xs opacity-50 mb-3">Upload a <code>.json</code> file exported from Socho. A new draft study will be created.</p>
              <form action="/studies/import-template" method="post" enctype="multipart/form-data" class="flex flex-col gap-2">
                <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
                <input type="file" name="file" accept=".json" class="file-input file-input-bordered file-input-sm w-full" required />
                <button type="submit" class="btn btn-primary btn-sm w-full">Import</button>
              </form>
            </div>
          </details>
          <.link href="/studies/new" class="btn btn-primary btn-sm">+ New Study</.link>
        </div>
      </div>

      <p :if={@studies == []} class="text-sm opacity-50">No studies yet.</p>

      <div class="space-y-2">
        <%= for study <- @studies do %>
          <div class="card bg-base-200 shadow p-4 flex flex-row items-center justify-between">
            <div class="space-y-1">
              <div class="font-semibold">{study.title}</div>
              <div class="flex gap-2 text-xs opacity-60">
                <span class="badge badge-sm">{study.status}</span>
                <span :if={study.client} class="badge badge-sm badge-secondary">
                  {study.client.name}
                </span>
                <span :if={!study.client} class="badge badge-sm badge-ghost">No client</span>
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
              <button
                phx-click="delete_study"
                phx-value-id={study.id}
                data-confirm={"Delete \"#{study.title}\"? This cannot be undone."}
                class="btn btn-sm btn-error btn-outline"
              >
                Delete
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    </Layouts.app>
    """
  end
end
