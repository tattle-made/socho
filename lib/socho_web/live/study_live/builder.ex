defmodule SochoWeb.StudyLive.Builder do
  use SochoWeb, :live_view

  alias Socho.Studies
  alias Socho.Studies.Registry

  # ── Mount ──────────────────────────────────────────────────────────────────

  @impl true
  def mount(_params, _session, socket) do
    registry = Registry.all()
    plugin_names = registry |> Map.keys() |> Enum.sort()

    {:ok,
     assign(socket,
       registry: registry,
       plugin_names: plugin_names,
       plugin_search: "",
       filtered_plugins: plugin_names,
       study_id: nil,
       study_title: "",
       trials: [],
       selected_trial_id: nil
     )}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    study = Studies.get_study!(id)

    trials =
      Enum.map(study.trials, fn t ->
        %{id: System.unique_integer([:positive]), plugin: t.plugin, config: t.config}
      end)

    {:noreply,
     assign(socket,
       study_id: study.id,
       study_title: study.title,
       trials: trials
     )}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # ── Events ─────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("study_title_changed", %{"value" => title}, socket) do
    {:noreply, assign(socket, study_title: title)}
  end

  def handle_event("plugin_search", %{"query" => query}, socket) do
    q = String.downcase(query)

    filtered =
      Enum.filter(socket.assigns.plugin_names, &String.contains?(String.downcase(&1), q))

    {:noreply, assign(socket, plugin_search: query, filtered_plugins: filtered)}
  end

  def handle_event("add_plugin_trial", %{"plugin" => name}, socket) do
    schema = socket.assigns.registry[name]
    config = build_defaults(schema["parameters"] || %{})
    trial = %{id: System.unique_integer([:positive]), plugin: name, config: config}

    {:noreply,
     assign(socket,
       trials: socket.assigns.trials ++ [trial],
       selected_trial_id: trial.id
     )}
  end

  def handle_event("select_trial", %{"id" => id_str}, socket) do
    {:noreply, assign(socket, selected_trial_id: String.to_integer(id_str))}
  end

  def handle_event("move_trial_up", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    {:noreply, assign(socket, trials: move_trial(socket.assigns.trials, id, :up))}
  end

  def handle_event("move_trial_down", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    {:noreply, assign(socket, trials: move_trial(socket.assigns.trials, id, :down))}
  end

  def handle_event("config_changed", %{"config" => params}, socket) do
    with id when not is_nil(id) <- socket.assigns.selected_trial_id,
         trial when not is_nil(trial) <- find_trial(socket.assigns.trials, id) do
      schema = socket.assigns.registry[trial.plugin]
      config = coerce_config(params, schema["parameters"] || %{})
      {:noreply, assign(socket, trials: update_trial_config(socket.assigns.trials, id, config))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("add_item", %{"param" => param_name}, socket) do
    with id when not is_nil(id) <- socket.assigns.selected_trial_id,
         trial when not is_nil(trial) <- find_trial(socket.assigns.trials, id) do
      schema = socket.assigns.registry[trial.plugin]
      nested = get_in(schema, ["parameters", param_name, "nested"]) || %{}
      new_item = build_defaults(nested)
      items = Map.get(trial.config, param_name) |> ensure_list()
      new_config = Map.put(trial.config, param_name, items ++ [new_item])
      {:noreply, assign(socket, trials: update_trial_config(socket.assigns.trials, id, new_config))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("remove_item", %{"param" => param_name, "index" => idx_str}, socket) do
    with id when not is_nil(id) <- socket.assigns.selected_trial_id,
         trial when not is_nil(trial) <- find_trial(socket.assigns.trials, id) do
      idx = String.to_integer(idx_str)
      items = Map.get(trial.config, param_name) |> ensure_list() |> List.delete_at(idx)
      new_config = Map.put(trial.config, param_name, items)
      {:noreply, assign(socket, trials: update_trial_config(socket.assigns.trials, id, new_config))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("remove_trial", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    trials = Enum.reject(socket.assigns.trials, &(&1.id == id))

    selected =
      if socket.assigns.selected_trial_id == id, do: nil, else: socket.assigns.selected_trial_id

    {:noreply, assign(socket, trials: trials, selected_trial_id: selected)}
  end

  def handle_event("save_study", _params, socket) do
    %{study_id: study_id, study_title: title, trials: trials} = socket.assigns

    result =
      if study_id,
        do: Studies.update_study_with_trials(study_id, title, trials),
        else: Studies.create_study_with_trials(title, trials)

    case result do
      {:ok, study} ->
        {:noreply, push_navigate(socket, to: "/study/#{study.id}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to save: #{inspect(reason)}")}
    end
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp find_trial(trials, id), do: Enum.find(trials, &(&1.id == id))

  defp update_trial_config(trials, id, new_config) do
    Enum.map(trials, fn t -> if t.id == id, do: %{t | config: new_config}, else: t end)
  end

  defp move_trial(trials, id, direction) do
    case Enum.find_index(trials, &(&1.id == id)) do
      nil -> trials
      idx -> do_move(trials, idx, direction)
    end
  end

  defp do_move(trials, 0, :up), do: trials
  defp do_move(trials, idx, :down) when idx == length(trials) - 1, do: trials
  defp do_move(trials, idx, :up), do: swap(trials, idx - 1, idx)
  defp do_move(trials, idx, :down), do: swap(trials, idx, idx + 1)

  defp swap(list, i, j) do
    a = Enum.at(list, i)
    b = Enum.at(list, j)
    list |> List.replace_at(i, b) |> List.replace_at(j, a)
  end

  defp build_defaults(parameters) do
    Map.new(parameters, fn {name, spec} ->
      val =
        cond do
          spec["type"] == "COMPLEX" and spec["array"] -> []
          spec["type"] == "COMPLEX" -> %{}
          spec["type"] == "BOOL" -> spec["default"] || false
          spec["default"] != nil -> to_string(spec["default"])
          true -> ""
        end

      {name, val}
    end)
  end

  defp coerce_config(params, parameters) do
    Map.new(params, fn {key, val} ->
      spec = parameters[key]

      coerced =
        case spec && spec["type"] do
          "INT" ->
            case Integer.parse(to_string(val)) do
              {n, _} -> n
              :error -> nil
            end

          "FLOAT" ->
            case Float.parse(to_string(val)) do
              {n, _} -> n
              :error -> nil
            end

          "BOOL" ->
            val == "true"

          "COMPLEX" ->
            if spec["array"] and is_map(val) do
              nested_params = spec["nested"] || %{}
              val
              |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end)
              |> Enum.map(fn {_, item} -> coerce_config(item, nested_params) end)
            else
              ensure_list(val)
            end

          _ ->
            if spec && spec["array"] && is_binary(val) do
              val |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
            else
              val
            end
        end

      {key, coerced}
    end)
  end

  defp ensure_list(nil), do: []
  defp ensure_list(list) when is_list(list), do: list
  defp ensure_list(_), do: []

  defp input_kind(%{"type" => "BOOL"}), do: :bool
  defp input_kind(%{"type" => "INT"}), do: :number
  defp input_kind(%{"type" => "FLOAT"}), do: :number
  defp input_kind(%{"type" => "HTML_STRING"}), do: :html
  defp input_kind(%{"type" => "COMPLEX", "array" => true}), do: :complex_array
  defp input_kind(%{"type" => "FUNCTION"}), do: :skip
  defp input_kind(%{"type" => "TIMELINE"}), do: :skip
  defp input_kind(_), do: :text

  defp sorted_params(parameters) do
    Enum.sort_by(parameters, fn {_, spec} ->
      if spec["type"] == "COMPLEX", do: 1, else: 0
    end)
  end

  # ── Template ───────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    selected_trial = Enum.find(assigns.trials, &(&1.id == assigns.selected_trial_id))
    assigns = assign(assigns, selected_trial: selected_trial)

    ~H"""
    <div class="flex flex-col gap-4 p-4" style="height: calc(100vh - 4rem);">
      <%!-- Header bar --%>
      <div class="flex items-center gap-3 shrink-0">
        <h1 class="text-xl font-bold shrink-0">
          Study Builder <span class="badge badge-warning">PoC</span>
        </h1>
        <input
          class="input input-bordered flex-1"
          type="text"
          placeholder="Study title"
          value={@study_title}
          phx-blur="study_title_changed"
        />
        <button
          class="btn btn-success shrink-0"
          phx-click="save_study"
          type="button"
          disabled={@study_title == "" or @trials == []}
        >
          Save & Preview
        </button>
      </div>

      <%!-- 3-column layout --%>
      <div class="grid gap-4 flex-1 min-h-0" style="grid-template-columns: 220px 400px 1fr;">

        <%!-- Column 1: Plugin picker --%>
        <div class="flex flex-col gap-2 min-h-0 border-r border-base-300 pr-4">
          <p class="text-xs font-semibold uppercase tracking-wider opacity-50 shrink-0">Add Block</p>

          <form phx-change="plugin_search" class="shrink-0">
            <input
              class="input input-bordered input-sm w-full"
              type="text"
              name="query"
              placeholder="Search plugins…"
              value={@plugin_search}
              phx-debounce="100"
              autocomplete="off"
            />
          </form>

          <div class="overflow-y-auto flex-1 space-y-0.5">
            <p :if={@filtered_plugins == []} class="text-sm opacity-50 px-2 py-1">
              No plugins found.
            </p>
            <%= for name <- @filtered_plugins do %>
              <button
                class="btn btn-sm btn-ghost w-full justify-start text-left font-normal truncate"
                phx-click="add_plugin_trial"
                phx-value-plugin={name}
                type="button"
              >
                {name}
              </button>
            <% end %>
          </div>
        </div>

        <%!-- Column 2: Trial blocks --%>
        <div class="flex flex-col gap-2 min-h-0">
          <p class="text-xs font-semibold uppercase tracking-wider opacity-50 shrink-0">
            Trials <span class="badge badge-neutral ml-1">{length(@trials)}</span>
          </p>

          <div class="overflow-y-auto flex-1 space-y-2">
            <p :if={@trials == []} class="text-sm opacity-50">
              Pick a plugin on the left to add a block.
            </p>

            <%= for {trial, position} <- Enum.with_index(@trials, 1) do %>
              <div class={"card shadow-sm border-2 transition-colors " <>
                if(@selected_trial_id == trial.id,
                  do: "bg-primary/10 border-primary",
                  else: "bg-base-200 border-transparent"
                )}>
                <div class="flex items-center gap-2 p-3">
                  <%!-- Clickable label area --%>
                  <div
                    class="flex items-center gap-2 flex-1 min-w-0 cursor-pointer"
                    phx-click="select_trial"
                    phx-value-id={trial.id}
                  >
                    <span class="badge badge-neutral shrink-0">#{position}</span>
                    <span class="text-sm font-medium truncate">{trial.plugin}</span>
                  </div>

                  <%!-- Reorder + remove controls --%>
                  <div class="flex items-center gap-0.5 shrink-0">
                    <button
                      class="btn btn-xs btn-ghost px-1"
                      phx-click="move_trial_up"
                      phx-value-id={trial.id}
                      type="button"
                      title="Move up"
                    >
                      ↑
                    </button>
                    <button
                      class="btn btn-xs btn-ghost px-1"
                      phx-click="move_trial_down"
                      phx-value-id={trial.id}
                      type="button"
                      title="Move down"
                    >
                      ↓
                    </button>
                    <button
                      class="btn btn-xs btn-ghost px-1 text-error"
                      phx-click="remove_trial"
                      phx-value-id={trial.id}
                      type="button"
                      title="Remove"
                    >
                      ✕
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Column 3: Config panel --%>
        <div class="flex flex-col gap-2 min-h-0 border-l border-base-300 pl-4">
          <%= if @selected_trial do %>
            <% schema = @registry[@selected_trial.plugin] %>
            <% params = sorted_params(schema["parameters"] || %{}) %>

            <p class="text-xs font-semibold uppercase tracking-wider opacity-50 shrink-0">
              Configure
            </p>
            <p class="text-sm font-medium text-primary shrink-0 -mt-1">{@selected_trial.plugin}</p>

            <div class="overflow-y-auto flex-1">
              <form
                phx-change="config_changed"
                id={"config-form-#{@selected_trial.id}"}
                class="space-y-3"
              >
                <p
                  :if={params == [] or Enum.all?(params, fn {_, s} -> input_kind(s) == :skip end)}
                  class="text-sm opacity-50"
                >
                  No configurable parameters.
                </p>
                <%= for {param_name, spec} <- params, input_kind(spec) != :skip do %>
                  <.param_field
                    param={param_name}
                    spec={spec}
                    kind={input_kind(spec)}
                    value={@selected_trial.config[param_name]}
                  />
                <% end %>
              </form>
            </div>
          <% else %>
            <p class="text-xs font-semibold uppercase tracking-wider opacity-50">Configure</p>
            <p class="text-sm opacity-40 mt-2">Click a trial block to configure it.</p>
          <% end %>
        </div>

      </div>
    </div>
    """
  end

  # ── Function Components ────────────────────────────────────────────────────

  attr :param, :string, required: true
  attr :prefix, :string, default: "config"
  attr :spec, :map, required: true
  attr :kind, :atom, required: true
  attr :value, :any, default: nil

  defp param_field(%{kind: :complex_array} = assigns) do
    items =
      case assigns.value do
        list when is_list(list) -> Enum.with_index(list)
        _ -> []
      end

    nested_params =
      (assigns.spec["nested"] || %{})
      |> Enum.sort()
      |> Enum.reject(fn {_, s} -> input_kind(s) == :skip end)

    assigns = assign(assigns, items: items, nested_params: nested_params)

    ~H"""
    <fieldset class="border border-base-300 rounded p-3 space-y-3">
      <legend class="px-1 text-sm font-semibold">
        {@param}
        <span class="text-xs font-normal opacity-50 ml-1">array</span>
      </legend>

      <%= for {item, idx} <- @items do %>
        <div class="border border-base-content/10 rounded p-2 space-y-2 bg-base-100">
          <div class="flex justify-between items-center">
            <span class="text-xs font-medium opacity-60">Item {idx + 1}</span>
            <button
              class="btn btn-xs btn-ghost text-error"
              phx-click="remove_item"
              phx-value-param={@param}
              phx-value-index={idx}
              type="button"
            >
              ✕ remove
            </button>
          </div>

          <%= for {field_name, field_spec} <- @nested_params do %>
            <.param_field
              param={field_name}
              prefix={"#{@prefix}[#{@param}][#{idx}]"}
              spec={field_spec}
              kind={input_kind(field_spec)}
              value={item[field_name]}
            />
          <% end %>
        </div>
      <% end %>

      <button
        class="btn btn-sm btn-outline w-full"
        phx-click="add_item"
        phx-value-param={@param}
        type="button"
      >
        + Add item
      </button>
    </fieldset>
    """
  end

  defp param_field(%{kind: :bool} = assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <input type="hidden" name={"#{@prefix}[#{@param}]"} value="false" />
      <input
        type="checkbox"
        class="checkbox checkbox-sm"
        name={"#{@prefix}[#{@param}]"}
        value="true"
        checked={@value == true or @value == "true"}
      />
      <label class="text-sm">{@param}</label>
    </div>
    """
  end

  defp param_field(%{kind: :number} = assigns) do
    ~H"""
    <div class="form-control">
      <label class="label py-1">
        <span class="label-text">{@param}</span>
        <span class="label-text-alt opacity-50">{@spec["type"]}</span>
      </label>
      <input
        type="number"
        class="input input-bordered input-sm"
        name={"#{@prefix}[#{@param}]"}
        value={@value || ""}
        step={if @spec["type"] == "FLOAT", do: "0.01", else: "1"}
        placeholder={to_string(@spec["default"] || "")}
      />
    </div>
    """
  end

  defp param_field(%{kind: :html} = assigns) do
    ~H"""
    <div class="form-control">
      <label class="label py-1">
        <span class="label-text">{@param}</span>
        <span class="label-text-alt opacity-50">HTML</span>
      </label>
      <textarea
        class="textarea textarea-bordered font-mono text-sm w-full"
        name={"#{@prefix}[#{@param}]"}
        rows="3"
        placeholder="<p>HTML content…</p>"
      >{@value}</textarea>
    </div>
    """
  end

  defp param_field(assigns) do
    display_value =
      cond do
        is_list(assigns.value) -> Enum.join(assigns.value, ", ")
        is_nil(assigns.value) -> ""
        true -> assigns.value
      end

    assigns = assign(assigns, display_value: display_value)

    ~H"""
    <div class="form-control">
      <label class="label py-1">
        <span class="label-text">{@param}</span>
        <span class="label-text-alt opacity-50">{@spec["type"]}{if @spec["array"], do: "[]", else: ""}</span>
      </label>
      <input
        type="text"
        class="input input-bordered input-sm"
        name={"#{@prefix}[#{@param}]"}
        value={@display_value}
        placeholder={
          cond do
            @spec["type"] == "KEYS" -> "ALL_KEYS · NO_KEYS · space,arrowleft"
            @spec["array"] -> "comma-separated values"
            true -> to_string(@spec["default"] || "")
          end
        }
      />
    </div>
    """
  end
end
