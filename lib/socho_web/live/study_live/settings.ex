defmodule SochoWeb.StudyLive.Settings do
  use SochoWeb, :live_view

  alias Socho.Clients
  alias Socho.Studies
  alias Socho.Studies.Study

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    study = Studies.get_study_meta!(id)
    clients = Clients.list_clients()
    changeset = Study.changeset(study, %{})

    {:ok,
     assign(socket,
       study: study,
       clients: clients,
       form: to_form(changeset),
       submission_count: Studies.count_submissions(id),
       study_url: SochoWeb.Endpoint.url() <> "/study/#{id}"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-xl mx-auto p-6 space-y-6">

        <div class="flex items-center gap-3">
          <.link href={"/studies/#{@study.id}/edit"} class="btn btn-ghost btn-sm">
            ← Builder
          </.link>
          <h1 class="text-2xl font-bold">Study Settings</h1>
        </div>

        <div class="card bg-base-200 shadow p-6">
          <.form for={@form} phx-submit="save" phx-change="validate" class="space-y-4">

            <div class="form-control">
              <label class="label">
                <span class="label-text font-medium">Title <span class="text-error">*</span></span>
              </label>
              <.input field={@form[:title]} type="text" placeholder="Study title" />
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text font-medium">Client</span>
              </label>
              <.input
                field={@form[:client_id]}
                type="select"
                prompt="No client"
                options={Enum.map(@clients, &{&1.name, &1.id})}
              />
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text font-medium">Status</span>
              </label>
              <.input
                field={@form[:status]}
                type="select"
                options={[{"Draft", :draft}, {"Published", :published}]}
              />
              <p class="text-xs opacity-50 mt-1">
                Only published studies appear in participant dashboards.
              </p>
              <div :if={@study.status == :published} class="mt-3">
                <p class="text-xs font-medium mb-1">Study URL</p>
                <input
                  type="text"
                  class="input input-bordered input-sm font-mono text-xs w-full"
                  value={@study_url}
                  readonly
                  onclick="this.select()"
                />
              </div>
            </div>

            <div class="pt-2">
              <.button phx-disable-with="Saving..." class="btn btn-primary">
                Save Settings
              </.button>
            </div>

          </.form>
        </div>

        <%!-- Export --%>
        <div class="card bg-base-200 shadow p-6">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-lg font-semibold">Export</h2>
              <p class="text-sm opacity-60 mt-0.5">
                Download this study as a JSON template that can be imported by any Socho user.
              </p>
            </div>
            <a href={"/studies/#{@study.id}/export-template"} class="btn btn-outline btn-sm">
              ↓ Export Template
            </a>
          </div>
        </div>

        <%!-- Submissions --%>
        <div class="card bg-base-200 shadow p-6">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-lg font-semibold">Submissions</h2>
              <p class="text-sm opacity-60 mt-0.5">
                {if @submission_count == 0, do: "No submissions yet.", else: "#{@submission_count} #{if @submission_count == 1, do: "submission", else: "submissions"} collected."}
              </p>
            </div>
            <a
              :if={@submission_count > 0}
              href={"/studies/#{@study.id}/export"}
              class="btn btn-outline btn-sm"
            >
              Export CSV
            </a>
          </div>
        </div>

      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"study" => params}, socket) do
    changeset =
      socket.assigns.study
      |> Study.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"study" => params}, socket) do
    case Studies.update_study(socket.assigns.study.id, params) do
      {:ok, study} ->
        changeset = Study.changeset(study, %{})

        {:noreply,
         socket
         |> put_flash(:info, "Settings saved.")
         |> assign(study: study, form: to_form(changeset))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
