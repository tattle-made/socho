defmodule SochoWeb.StudyLive.Builder do
  use SochoWeb, :live_view

  alias Socho.Studies.Registry

  # ── Mount ──────────────────────────────────────────────────────────────────

  @impl true
  def mount(_params, _session, socket) do
    registry = Registry.all()

    {:ok,
     assign(socket,
       registry: registry,
       plugin_names: registry |> Map.keys() |> Enum.sort(),
       study_title: "",
       trials: [],
       # current "add trial" panel state
       selected_plugin: nil,
       current_config: %{}
     )}
  end

  # ── Events ─────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("study_title_changed", %{"title" => title}, socket) do
    {:noreply, assign(socket, study_title: title)}
  end

  def handle_event("select_plugin", %{"plugin" => ""}, socket) do
    {:noreply, assign(socket, selected_plugin: nil, current_config: %{})}
  end

  def handle_event("select_plugin", %{"plugin" => name}, socket) do
    schema = socket.assigns.registry[name]
    {:noreply,
     assign(socket,
       selected_plugin: name,
       current_config: build_defaults(schema["parameters"] || %{})
     )}
  end

  # Main form change — covers all simple params AND existing complex-array item fields
  def handle_event("config_changed", %{"config" => params}, socket) do
    schema = socket.assigns.registry[socket.assigns.selected_plugin]
    config = coerce_config(params, schema["parameters"] || %{})
    {:noreply, assign(socket, current_config: config)}
  end

  # Add a new blank item to a COMPLEX array param
  def handle_event("add_item", %{"param" => param_name}, socket) do
    schema = socket.assigns.registry[socket.assigns.selected_plugin]
    nested = get_in(schema, ["parameters", param_name, "nested"]) || %{}
    new_item = build_defaults(nested)

    current = socket.assigns.current_config
    items = Map.get(current, param_name) |> ensure_list()
    {:noreply, assign(socket, current_config: Map.put(current, param_name, items ++ [new_item]))}
  end

  # Remove an item from a COMPLEX array param
  def handle_event("remove_item", %{"param" => param_name, "index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    current = socket.assigns.current_config
    items = Map.get(current, param_name) |> ensure_list() |> List.delete_at(idx)
    {:noreply, assign(socket, current_config: Map.put(current, param_name, items))}
  end

  def handle_event("add_trial", _params, socket) do
    trial = %{
      id: System.unique_integer([:positive]),
      plugin: socket.assigns.selected_plugin,
      config: socket.assigns.current_config
    }

    {:noreply,
     assign(socket,
       trials: socket.assigns.trials ++ [trial],
       selected_plugin: nil,
       current_config: %{}
     )}
  end

  def handle_event("remove_trial", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    {:noreply, assign(socket, trials: Enum.reject(socket.assigns.trials, &(&1.id == id)))}
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

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

  # Parse raw form strings into typed values, and normalise COMPLEX arrays
  # (Phoenix parses config[questions][0][prompt] as %{"0" => %{...}}).
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
              # Convert %{"0" => item, "1" => item} → [item, item]
              val
              |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end)
              |> Enum.map(fn {_, item} -> item end)
            else
              ensure_list(val)
            end

          _ ->
            val
        end

      {key, coerced}
    end)
  end

  defp ensure_list(nil), do: []
  defp ensure_list(list) when is_list(list), do: list
  defp ensure_list(_), do: []

  # Maps a registry type string to a render atom used in the template
  defp input_kind(%{"type" => "BOOL"}), do: :bool
  defp input_kind(%{"type" => "INT"}), do: :number
  defp input_kind(%{"type" => "FLOAT"}), do: :number
  defp input_kind(%{"type" => "HTML_STRING"}), do: :html
  defp input_kind(%{"type" => "COMPLEX", "array" => true}), do: :complex_array
  defp input_kind(%{"type" => "FUNCTION"}), do: :skip
  defp input_kind(%{"type" => "TIMELINE"}), do: :skip
  defp input_kind(_), do: :text

  # Sort so COMPLEX array params appear at the bottom of the form
  defp sorted_params(parameters) do
    Enum.sort_by(parameters, fn {_, spec} ->
      if spec["type"] == "COMPLEX", do: 1, else: 0
    end)
  end

  # ── Template ───────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto p-6 space-y-6">
      <h1 class="text-2xl font-bold">Study Builder <span class="badge badge-warning">PoC</span></h1>

      <%!-- Study metadata --%>
      <div class="card bg-base-200 shadow p-4 space-y-2">
        <h2 class="font-semibold">Study Details</h2>
        <input
          class="input input-bordered w-full"
          type="text"
          name="title"
          placeholder="Study title"
          value={@study_title}
          phx-blur="study_title_changed"
        />
      </div>

      <%!-- Add trial panel --%>
      <div class="card bg-base-200 shadow p-4 space-y-4">
        <h2 class="font-semibold">Add Trial Block</h2>

        <form phx-change="select_plugin">
          <select class="select select-bordered w-full" name="plugin">
            <option value="">— select a plugin —</option>
            <%= for name <- @plugin_names do %>
              <option value={name} selected={@selected_plugin == name}>{name}</option>
            <% end %>
          </select>
        </form>

        <%= if @selected_plugin do %>
          <% schema = @registry[@selected_plugin] %>
          <% params = sorted_params(schema["parameters"] || %{}) %>

          <form phx-change="config_changed" id="config-form" class="space-y-3">
            <%= for {param_name, spec} <- params, input_kind(spec) != :skip do %>
              <.param_field
                param={param_name}
                spec={spec}
                kind={input_kind(spec)}
                value={@current_config[param_name]}
              />
            <% end %>
          </form>

          <div class="flex justify-end pt-2">
            <button class="btn btn-primary" phx-click="add_trial" type="button">
              + Add to Study
            </button>
          </div>
        <% end %>
      </div>

      <%!-- Trial list --%>
      <div class="space-y-2">
        <h2 class="font-semibold">
          Trials
          <span class="badge badge-neutral ml-1">{length(@trials)}</span>
        </h2>

        <p :if={@trials == []} class="text-sm opacity-50">No trials yet.</p>

        <%= for {trial, position} <- Enum.with_index(@trials, 1) do %>
          <div class="card bg-base-300 shadow p-4 space-y-2">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <span class="badge badge-neutral">#{position}</span>
                <span class="badge badge-primary">{trial.plugin}</span>
              </div>
              <button
                class="btn btn-xs btn-error btn-outline"
                phx-click="remove_trial"
                phx-value-id={trial.id}
              >
                Remove
              </button>
            </div>
            <pre class="text-xs bg-base-100 rounded p-2 overflow-x-auto">{Jason.encode!(trial.config, pretty: true)}</pre>
          </div>
        <% end %>
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

  # COMPLEX array — renders a list of nested-item sub-forms + add/remove controls
  defp param_field(%{kind: :complex_array} = assigns) do
    # Preprocess in function body — avoids unreliable <% %> blocks inside ~H
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

  # BOOL — checkbox with hidden "false" fallback (unchecked checkboxes aren't sent)
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

  # INT / FLOAT
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

  # HTML_STRING — textarea since the value is markup
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

  # STRING, KEYS, IMAGE, AUDIO, VIDEO, OBJECT → plain text input
  defp param_field(assigns) do
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
        value={@value || ""}
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
