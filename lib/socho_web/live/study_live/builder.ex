defmodule SochoWeb.StudyLive.Builder do
  use SochoWeb, :live_view

  alias Socho.Clients
  alias Socho.Studies
  alias Socho.Studies.Registry
  alias Socho.Studies.Templates
  alias SochoWeb.StudyLive.SurveyBuilderComponent

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
       study_client_id: nil,
       clients: Clients.list_clients(),
       trials: [],
       selected_trial_id: nil,
       show_preview: false,
       preview_key: 0,
       sidebar_tab: :blocks,
       templates: Templates.all(),
       template_group_key: 0
     )}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    study = Studies.get_study!(id)
    trials = Enum.map(study.trials, &db_trial_to_node/1)

    {:noreply,
     assign(socket,
       study_id: study.id,
       study_title: study.title,
       study_client_id: study.client_id,
       trials: trials
     )}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # ── Events ─────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("study_title_changed", %{"value" => title}, socket) do
    {:noreply, assign(socket, study_title: title)}
  end

  def handle_event("study_client_changed", %{"value" => client_id_str}, socket) do
    client_id = if client_id_str == "", do: nil, else: String.to_integer(client_id_str)
    {:noreply, assign(socket, study_client_id: client_id)}
  end

  def handle_event("plugin_search", %{"query" => query}, socket) do
    q = String.downcase(query)

    filtered =
      Enum.filter(socket.assigns.plugin_names, &String.contains?(String.downcase(&1), q))

    {:noreply, assign(socket, plugin_search: query, filtered_plugins: filtered)}
  end

  def handle_event("add_timeline", _params, socket) do
    node = %{
      id: System.unique_integer([:positive]),
      node_type: "timeline",
      plugin: nil,
      config: %{
        "timeline_variables" => [],
        "repetitions" => 1,
        "randomize_order" => false,
        "conditional_function" => "",
        "loop_function" => ""
      },
      extensions: %{},
      children: []
    }

    {:noreply,
     assign(socket,
       trials: socket.assigns.trials ++ [node],
       selected_trial_id: node.id
     )}
  end

  def handle_event("add_plugin_trial", %{"plugin" => name}, socket) do
    schema = socket.assigns.registry[name]
    config = build_defaults(schema["parameters"] || %{}) |> Map.put("data_tag", "")

    trial = %{
      id: System.unique_integer([:positive]),
      node_type: "trial",
      plugin: name,
      config: config,
      extensions: %{},
      children: []
    }

    selected = find_node(socket.assigns.trials, socket.assigns.selected_trial_id)

    trials =
      if selected && selected.node_type == "timeline" do
        add_child_to_node(socket.assigns.trials, selected.id, trial)
      else
        socket.assigns.trials ++ [trial]
      end

    {:noreply, assign(socket, trials: trials, selected_trial_id: trial.id)}
  end

  def handle_event("select_trial", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    node = find_node(socket.assigns.trials, id)

    extra =
      if node && node.node_type == "template_group",
        do: [template_group_key: System.unique_integer([:positive])],
        else: []

    {:noreply, assign(socket, [{:selected_trial_id, id} | extra])}
  end

  def handle_event("move_trial_up", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    {:noreply, assign(socket, trials: move_node_in_tree(socket.assigns.trials, id, :up))}
  end

  def handle_event("move_trial_down", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    {:noreply, assign(socket, trials: move_node_in_tree(socket.assigns.trials, id, :down))}
  end

  @impl true
  def handle_info({:survey_builder_update, survey_json}, socket) do
    with id when not is_nil(id) <- socket.assigns.selected_trial_id,
         node when not is_nil(node) <- find_node(socket.assigns.trials, id) do
      new_config = Map.put(node.config, "survey_json", survey_json)
      {:noreply, assign(socket, trials: update_node_config(socket.assigns.trials, id, new_config))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("config_changed", %{"config" => params}, socket) do
    with id when not is_nil(id) <- socket.assigns.selected_trial_id,
         node when not is_nil(node) <- find_node(socket.assigns.trials, id) do
      config =
        if node.node_type == "timeline" do
          coerce_timeline_config(params)
        else
          schema = socket.assigns.registry[node.plugin]
          coerce_config(params, schema["parameters"] || %{})
        end

      {:noreply, assign(socket, trials: update_node_config(socket.assigns.trials, id, config))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("toggle_extension", %{"ext" => ext_name}, socket) do
    with id when not is_nil(id) <- socket.assigns.selected_trial_id,
         node when not is_nil(node) <- find_node(socket.assigns.trials, id) do
      ext_cfg = get_in(node.extensions || %{}, [ext_name]) || %{}
      enabled = Map.get(ext_cfg, "enabled", false)
      new_ext_cfg = Map.put(ext_cfg, "enabled", !enabled)

      new_ext_cfg =
        if ext_name == "touchscreen-buttons" && !enabled && !Map.has_key?(ext_cfg, "buttons") do
          Map.put(new_ext_cfg, "buttons", default_tsb_buttons())
        else
          new_ext_cfg
        end

      new_extensions = Map.put(node.extensions || %{}, ext_name, new_ext_cfg)
      {:noreply, assign(socket, trials: update_node_extensions(socket.assigns.trials, id, new_extensions))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("add_tsb_button", %{"ext" => ext_name}, socket) do
    with id when not is_nil(id) <- socket.assigns.selected_trial_id,
         node when not is_nil(node) <- find_node(socket.assigns.trials, id) do
      ext_cfg = get_in(node.extensions || %{}, [ext_name]) || %{}
      buttons = Map.get(ext_cfg, "buttons", [])
      new_button = %{"key" => "e", "preset" => "left", "label" => "←", "color" => ""}
      new_ext_cfg = Map.put(ext_cfg, "buttons", buttons ++ [new_button])
      new_extensions = Map.put(node.extensions || %{}, ext_name, new_ext_cfg)
      {:noreply, assign(socket, trials: update_node_extensions(socket.assigns.trials, id, new_extensions))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("remove_tsb_button", %{"ext" => ext_name, "index" => idx_str}, socket) do
    with id when not is_nil(id) <- socket.assigns.selected_trial_id,
         node when not is_nil(node) <- find_node(socket.assigns.trials, id) do
      idx = String.to_integer(idx_str)
      ext_cfg = get_in(node.extensions || %{}, [ext_name]) || %{}
      buttons = Map.get(ext_cfg, "buttons", []) |> List.delete_at(idx)
      new_ext_cfg = Map.put(ext_cfg, "buttons", buttons)
      new_extensions = Map.put(node.extensions || %{}, ext_name, new_ext_cfg)
      {:noreply, assign(socket, trials: update_node_extensions(socket.assigns.trials, id, new_extensions))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("tsb_button_changed", %{"ext" => ext_name, "index" => idx_str, "button" => params}, socket) do
    with id when not is_nil(id) <- socket.assigns.selected_trial_id,
         node when not is_nil(node) <- find_node(socket.assigns.trials, id) do
      idx = String.to_integer(idx_str)
      ext_cfg = get_in(node.extensions || %{}, [ext_name]) || %{}
      buttons = Map.get(ext_cfg, "buttons", [])
      updated = Map.merge(Enum.at(buttons, idx, %{}), params)
      new_ext_cfg = Map.put(ext_cfg, "buttons", List.replace_at(buttons, idx, updated))
      new_extensions = Map.put(node.extensions || %{}, ext_name, new_ext_cfg)
      {:noreply, assign(socket, trials: update_node_extensions(socket.assigns.trials, id, new_extensions))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("add_item", %{"param" => param_name}, socket) do
    with id when not is_nil(id) <- socket.assigns.selected_trial_id,
         node when not is_nil(node) <- find_node(socket.assigns.trials, id) do
      schema = socket.assigns.registry[node.plugin]
      nested = get_in(schema, ["parameters", param_name, "nested"]) || %{}
      new_item = build_defaults(nested)
      items = Map.get(node.config, param_name) |> ensure_list()
      new_config = Map.put(node.config, param_name, items ++ [new_item])
      {:noreply, assign(socket, trials: update_node_config(socket.assigns.trials, id, new_config))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("remove_item", %{"param" => param_name, "index" => idx_str}, socket) do
    with id when not is_nil(id) <- socket.assigns.selected_trial_id,
         node when not is_nil(node) <- find_node(socket.assigns.trials, id) do
      idx = String.to_integer(idx_str)
      items = Map.get(node.config, param_name) |> ensure_list() |> List.delete_at(idx)
      new_config = Map.put(node.config, param_name, items)
      {:noreply, assign(socket, trials: update_node_config(socket.assigns.trials, id, new_config))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("remove_trial", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    trials = remove_node_from_tree(socket.assigns.trials, id)

    selected =
      if socket.assigns.selected_trial_id == id or
           find_node(trials, socket.assigns.selected_trial_id) == nil,
         do: nil,
         else: socket.assigns.selected_trial_id

    {:noreply, assign(socket, trials: trials, selected_trial_id: selected)}
  end

  def handle_event("save_study", _params, socket) do
    %{study_id: study_id, study_client_id: client_id, trials: trials} = socket.assigns
    title = if socket.assigns.study_title == "", do: "Untitled Study", else: socket.assigns.study_title
    trial_maps = Enum.map(trials, &node_to_map/1)

    result =
      if study_id,
        do: Studies.update_study_with_trials(study_id, title, client_id, trial_maps),
        else: Studies.create_study_with_trials(title, client_id, trial_maps)

    case result do
      {:ok, study} ->
        {:noreply,
         socket
         |> assign(study_id: study.id, preview_key: socket.assigns.preview_key + 1)
         |> put_flash(:info, "Saved")
         |> push_patch(to: "/studies/#{study.id}/edit")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to save: #{inspect(reason)}")}
    end
  end

  def handle_event("switch_sidebar_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, sidebar_tab: String.to_existing_atom(tab))}
  end

  def handle_event("insert_template", %{"id" => tpl_id}, socket) do
    tpl = Templates.get(tpl_id)
    vars = Map.new(tpl.variables, &{&1.key, &1.default})
    children = tpl.build.(vars) |> stamp_ids()

    group = %{
      id: System.unique_integer([:positive]),
      node_type: "template_group",
      plugin: nil,
      config: %{"template_id" => tpl_id, "template_name" => tpl.name, "vars" => vars},
      extensions: %{},
      children: children
    }

    {:noreply,
     assign(socket,
       trials: socket.assigns.trials ++ [group],
       selected_trial_id: group.id,
       template_group_key: System.unique_integer([:positive])
     )}
  end

  def handle_event("template_vars_changed", %{"vars" => vars}, socket) do
    with id when not is_nil(id) <- socket.assigns.selected_trial_id,
         %{node_type: "template_group"} = node <- find_node(socket.assigns.trials, id) do
      tpl = Templates.get(node.config["template_id"])
      children = tpl.build.(vars) |> stamp_ids()
      new_config = %{"template_id" => node.config["template_id"], "template_name" => node.config["template_name"], "vars" => vars}

      trials =
        socket.assigns.trials
        |> update_node_config(id, new_config)
        |> update_node_children(id, children)

      {:noreply, assign(socket, trials: trials)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("toggle_preview", _params, socket) do
    {:noreply, assign(socket, show_preview: !socket.assigns.show_preview)}
  end

  def handle_event("reload_preview", _params, socket) do
    {:noreply, assign(socket, preview_key: socket.assigns.preview_key + 1)}
  end

  # ── Tree Helpers ────────────────────────────────────────────────────────────

  defp stamp_ids(nodes) do
    Enum.map(nodes, fn node ->
      node
      |> Map.put(:id, System.unique_integer([:positive]))
      |> Map.update(:children, [], &stamp_ids/1)
    end)
  end

  defp db_trial_to_node(trial) do
    %{
      id: System.unique_integer([:positive]),
      node_type: trial.node_type,
      plugin: trial.plugin,
      config: trial.config,
      extensions: trial.extensions || %{},
      children: Enum.map(trial.children, &db_trial_to_node/1)
    }
  end

  defp node_to_map(node) do
    %{
      node_type: node.node_type,
      plugin: node.plugin,
      config: node.config,
      extensions: node.extensions || %{},
      children: Enum.map(node.children || [], &node_to_map/1)
    }
  end

  defp find_node(_nodes, nil), do: nil

  defp find_node(nodes, id) do
    Enum.find_value(nodes, fn node ->
      if node.id == id, do: node, else: find_node(node.children, id)
    end)
  end

  defp update_node_config(nodes, id, new_config) do
    Enum.map(nodes, fn node ->
      if node.id == id do
        %{node | config: new_config}
      else
        %{node | children: update_node_config(node.children, id, new_config)}
      end
    end)
  end

  defp update_node_children(nodes, id, new_children) do
    Enum.map(nodes, fn node ->
      if node.id == id do
        %{node | children: new_children}
      else
        %{node | children: update_node_children(node.children, id, new_children)}
      end
    end)
  end

  defp update_node_extensions(nodes, id, new_extensions) do
    Enum.map(nodes, fn node ->
      if node.id == id do
        %{node | extensions: new_extensions}
      else
        %{node | children: update_node_extensions(node.children, id, new_extensions)}
      end
    end)
  end

  defp remove_node_from_tree(nodes, id) do
    nodes
    |> Enum.reject(&(&1.id == id))
    |> Enum.map(fn node -> %{node | children: remove_node_from_tree(node.children, id)} end)
  end

  defp add_child_to_node(nodes, parent_id, new_node) do
    Enum.map(nodes, fn node ->
      if node.id == parent_id do
        %{node | children: node.children ++ [new_node]}
      else
        %{node | children: add_child_to_node(node.children, parent_id, new_node)}
      end
    end)
  end

  defp move_node_in_tree(nodes, id, direction) do
    idx = Enum.find_index(nodes, &(&1.id == id))

    if idx != nil do
      do_move(nodes, idx, direction)
    else
      Enum.map(nodes, fn node ->
        %{node | children: move_node_in_tree(node.children, id, direction)}
      end)
    end
  end

  defp do_move(nodes, 0, :up), do: nodes
  defp do_move(nodes, idx, :down) when idx == length(nodes) - 1, do: nodes
  defp do_move(nodes, idx, :up), do: swap(nodes, idx - 1, idx)
  defp do_move(nodes, idx, :down), do: swap(nodes, idx, idx + 1)

  defp swap(list, i, j) do
    a = Enum.at(list, i)
    b = Enum.at(list, j)
    list |> List.replace_at(i, b) |> List.replace_at(j, a)
  end

  # ── Config Helpers ──────────────────────────────────────────────────────────

  defp coerce_timeline_config(params) do
    timeline_vars =
      case Jason.decode(params["timeline_variables"] || "[]") do
        {:ok, list} when is_list(list) -> list
        _ -> []
      end

    repetitions =
      case Integer.parse(to_string(params["repetitions"] || "1")) do
        {n, _} -> max(n, 1)
        :error -> 1
      end

    %{
      "timeline_variables" => timeline_vars,
      "repetitions" => repetitions,
      "randomize_order" => params["randomize_order"] == "true",
      "conditional_function" => String.trim(params["conditional_function"] || ""),
      "loop_function" => String.trim(params["loop_function"] || "")
    }
  end

  defp build_defaults(parameters) do
    Map.new(parameters, fn {name, spec} ->
      val =
        cond do
          spec["type"] == "COMPLEX" and spec["array"] -> []
          spec["type"] == "COMPLEX" -> %{}
          spec["type"] == "OBJECT" -> %{}
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

          "OBJECT" ->
            case val do
              val when is_map(val) -> val
              val when is_binary(val) ->
                case Jason.decode(val) do
                  {:ok, map} when is_map(map) -> map
                  _ -> %{}
                end
              _ -> %{}
            end

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
  defp input_kind(%{"type" => "OBJECT"}), do: :json
  defp input_kind(%{"type" => "FUNCTION"}), do: :skip
  defp input_kind(%{"type" => "TIMELINE"}), do: :skip
  defp input_kind(_), do: :text

  defp sorted_params(parameters) do
    Enum.sort_by(parameters, fn {_, spec} ->
      if spec["type"] == "COMPLEX", do: 1, else: 0
    end)
  end

  defp default_tsb_buttons do
    [
      %{"key" => "e", "preset" => "left", "label" => "←", "color" => ""},
      %{"key" => "i", "preset" => "right", "label" => "→", "color" => ""}
    ]
  end

  @tsb_presets [
    {"left", "Fill left"},
    {"right", "Fill right"},
    {"left_middle", "Left middle"},
    {"right_middle", "Right middle"},
    {"fill_bottom", "Fill bottom"},
    {"bottom_left", "Bottom left"},
    {"bottom_right", "Bottom right"},
    {"top_left", "Top left"},
    {"top_right", "Top right"}
  ]

  defp available_extensions do
    [
      %{
        name: "touchscreen-buttons",
        label: "Touchscreen Buttons",
        description: "Show on-screen tap zones for keyboard responses on touch devices."
      }
    ]
  end

  # ── Template ───────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    selected_trial =
      if assigns.selected_trial_id,
        do: find_node(assigns.trials, assigns.selected_trial_id),
        else: nil

    selected_template =
      if selected_trial && selected_trial.node_type == "template_group" do
        Templates.get(selected_trial.config["template_id"])
      end

    assigns =
      assign(assigns,
        selected_trial: selected_trial,
        selected_template: selected_template,
        tsb_presets: @tsb_presets
      )

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
    <div class="flex flex-col gap-6 p-4">
      <%!-- Header bar --%>
      <div class="flex items-center gap-3 shrink-0">
        <h1 class="text-xl font-bold shrink-0">Study Builder</h1>
        <div class="flex-1" />
        <.link
          :if={@study_id}
          href={"/studies/#{@study_id}/settings"}
          class="btn btn-ghost btn-sm shrink-0"
          title="Study settings"
        >
          <.icon name="hero-cog-6-tooth" class="size-5" />
        </.link>
        <button
          :if={@study_id}
          class={["btn btn-sm shrink-0", if(@show_preview, do: "btn-primary", else: "btn-outline")]}
          phx-click="toggle_preview"
          type="button"
          title="Toggle live preview"
        >
          👁 Preview
        </button>
        <button
          class="btn btn-success shrink-0"
          phx-click="save_study"
          type="button"
          disabled={@trials == []}
        >
          Save
        </button>
      </div>

      <%!-- Blocks / Templates strip --%>
      <div class="shrink-0 border-b border-base-300 pb-3 flex flex-col gap-2">

        <%!-- Tab bar --%>
        <div role="tablist" class="tabs tabs-bordered tabs-sm">
          <button
            role="tab"
            class={["tab", if(@sidebar_tab == :blocks, do: "tab-active")]}
            phx-click="switch_sidebar_tab"
            phx-value-tab="blocks"
            type="button"
          >
            Blocks
          </button>
          <button
            role="tab"
            class={["tab", if(@sidebar_tab == :templates, do: "tab-active")]}
            phx-click="switch_sidebar_tab"
            phx-value-tab="templates"
            type="button"
          >
            Templates
          </button>
        </div>

        <%!-- Blocks tab content --%>
        <%= if @sidebar_tab == :blocks do %>
          <div class="flex items-center gap-2 shrink-0">
            <button
              class="btn btn-sm btn-outline btn-secondary shrink-0"
              phx-click="add_timeline"
              type="button"
            >
              + Timeline Group
            </button>
            <form phx-change="plugin_search">
              <input
                class="input input-bordered input-sm w-44"
                type="text"
                name="query"
                placeholder="Search plugins…"
                value={@plugin_search}
                phx-debounce="100"
                autocomplete="off"
              />
            </form>
          </div>
          <div class="flex gap-2 overflow-x-auto pb-1">
            <p :if={@filtered_plugins == []} class="text-sm opacity-50 px-2 self-center">No plugins found.</p>
            <%= for name <- @filtered_plugins do %>
              <% meta = @registry[name] %>
              <button
                class="btn btn-ghost shrink-0 w-44 h-auto py-2 px-3 font-normal border border-base-200 hover:border-primary flex flex-col items-start text-left"
                phx-click="add_plugin_trial"
                phx-value-plugin={name}
                type="button"
              >
                <div class="flex items-center gap-1 w-full">
                  <span class="text-sm font-medium leading-tight">{name}</span>
                  <span :if={meta["custom"]} class="badge badge-accent badge-xs ml-auto">custom</span>
                </div>
                <span :if={meta["description"]} class="text-xs opacity-50 leading-tight whitespace-normal text-left mt-0.5">
                  {meta["description"]}
                </span>
              </button>
            <% end %>
          </div>
        <% end %>

        <%!-- Templates tab content --%>
        <%= if @sidebar_tab == :templates do %>
          <div class="flex gap-2 overflow-x-auto pb-1">
            <%= for tpl <- @templates do %>
              <button
                class="btn btn-ghost shrink-0 w-52 h-auto py-2 px-3 font-normal border border-base-200 hover:border-primary flex flex-col items-start text-left"
                phx-click="insert_template"
                phx-value-id={tpl.id}
                type="button"
              >
                <span class="text-sm font-semibold leading-tight">{tpl.name}</span>
                <span class="text-xs opacity-50 leading-tight whitespace-normal text-left mt-0.5">{tpl.description}</span>
              </button>
            <% end %>
          </div>
        <% end %>

      </div>

      <%!-- 2-column layout (3rd column added when preview is open) --%>
      <div
        class="grid gap-6 items-start"
        style={if @show_preview && @study_id, do: "grid-template-columns: 320px 1fr 360px", else: "grid-template-columns: 320px 1fr"}
      >

        <%!-- Column 1: Trial tree --%>
        <div class="flex flex-col gap-2">
          <p class="text-xs font-semibold uppercase tracking-wider opacity-50">
            Trials <span class="badge badge-neutral ml-1">{length(@trials)}</span>
          </p>

          <div class="space-y-2">
            <p :if={@trials == []} class="text-sm opacity-50">
              Pick a plugin above to add a block.
            </p>

            <%= for {node, position} <- Enum.with_index(@trials, 1) do %>
              <.node_block node={node} position={position} selected_id={@selected_trial_id} />
            <% end %>
          </div>
        </div>

        <%!-- Column 2: Config panel --%>
        <div class="flex flex-col gap-2 border-l border-base-300 pl-4">
          <%= if @selected_trial && @selected_trial.node_type == "template_group" do %>
            <p class="text-xs font-semibold uppercase tracking-wider opacity-50 shrink-0">Configure</p>
            <p class="text-sm font-medium text-accent shrink-0 -mt-1">{@selected_template && @selected_template.name}</p>

            <div>
              <form
                phx-change="template_vars_changed"
                id={"template-vars-form-#{@template_group_key}"}
                class="space-y-5"
              >
                <%= for var <- (@selected_template && @selected_template.variables) || [] do %>
                  <% current_vars = @selected_trial.config["vars"] || %{} %>
                  <div class="form-control">
                    <p class="text-sm font-medium leading-tight">{var.label}</p>
                    <p class="text-xs opacity-40 mt-0.5 mb-1">
                      {if var.type == :int, do: "INT", else: "TEXT"}
                    </p>
                    <textarea
                      :if={var.type == :text}
                      id={"tvar-#{@template_group_key}-#{var.key}"}
                      class="textarea textarea-bordered textarea-sm text-xs font-mono leading-snug w-full"
                      name={"vars[#{var.key}]"}
                      rows="4"
                    >{Map.get(current_vars, var.key, var.default)}</textarea>
                    <input
                      :if={var.type == :int}
                      id={"tvar-#{@template_group_key}-#{var.key}"}
                      type="number"
                      class="input input-bordered input-sm w-full"
                      name={"vars[#{var.key}]"}
                      value={Map.get(current_vars, var.key, var.default)}
                      step="1"
                    />
                  </div>
                <% end %>
              </form>
            </div>
          <% else %>
          <%= if @selected_trial && @selected_trial.node_type == "timeline" do %>
            <p class="text-xs font-semibold uppercase tracking-wider opacity-50 shrink-0">Configure</p>
            <p class="text-sm font-medium text-secondary shrink-0 -mt-1">Timeline Group</p>

            <div>
              <form
                phx-change="config_changed"
                id={"config-form-#{@selected_trial.id}"}
                class="space-y-5"
              >
                <div class="form-control">
                  <p class="text-sm font-medium leading-tight">timeline_variables</p>
                  <p class="text-xs opacity-40 mt-0.5 mb-1">JSON array</p>
                  <textarea
                    class="textarea textarea-bordered text-xs font-mono w-full"
                    name="config[timeline_variables]"
                    rows="6"
                    placeholder={"[{\"stimulus\": \"hello\"}, {\"stimulus\": \"world\"}]"}
                  >{Jason.encode!(@selected_trial.config["timeline_variables"] || [])}</textarea>
                  <p class="text-xs opacity-50 mt-1">
                    In trial params, use <code class="font-mono">{"{{varName}}"}</code> to reference a variable.
                  </p>
                </div>

                <div class="form-control">
                  <p class="text-sm font-medium leading-tight">repetitions</p>
                  <p class="text-xs opacity-40 mt-0.5 mb-1">INT</p>
                  <input
                    type="number"
                    class="input input-bordered input-sm w-full"
                    name="config[repetitions]"
                    value={@selected_trial.config["repetitions"] || 1}
                    min="1"
                    step="1"
                  />
                </div>

                <div>
                  <p class="text-sm font-medium leading-tight mb-1">randomize_order</p>
                  <div class="flex items-center gap-2">
                    <input type="hidden" name="config[randomize_order]" value="false" />
                    <input
                      type="checkbox"
                      class="checkbox checkbox-sm"
                      name="config[randomize_order]"
                      value="true"
                      checked={@selected_trial.config["randomize_order"] == true}
                    />
                    <span class="text-xs opacity-40">BOOL</span>
                  </div>
                </div>

                <div class="divider text-xs my-1">Conditional Logic</div>

                <div class="form-control">
                  <p class="text-sm font-medium leading-tight">Skip unless…</p>
                  <p class="text-xs opacity-40 mt-0.5 mb-1">conditional_function</p>
                  <textarea
                    class="textarea textarea-bordered text-xs font-mono leading-snug w-full"
                    name="config[conditional_function]"
                    rows="4"
                    placeholder={"// Return true to run this block, false to skip it\nconst d = jsPsych.data.get().last(1).values()[0];\nreturn d.response === \"yes\";"}
                    phx-debounce="300"
                  >{@selected_trial.config["conditional_function"] || ""}</textarea>
                  <p class="text-xs opacity-50 mt-1 leading-snug">
                    JS function body. Return <code class="font-mono">true</code> to run this block, <code class="font-mono">false</code> to skip it entirely.
                    Use <code class="font-mono">jsPsych.data.get()</code> to access previous responses.
                  </p>
                </div>

                <div class="form-control">
                  <p class="text-sm font-medium leading-tight">Repeat while…</p>
                  <p class="text-xs opacity-40 mt-0.5 mb-1">loop_function</p>
                  <textarea
                    class="textarea textarea-bordered text-xs font-mono leading-snug w-full"
                    name="config[loop_function]"
                    rows="4"
                    placeholder={"// data = DataCollection from the last iteration\n// Return true to repeat, false to continue\nreturn data.select(\"correct\").mean() < 0.8;"}
                    phx-debounce="300"
                  >{@selected_trial.config["loop_function"] || ""}</textarea>
                  <p class="text-xs opacity-50 mt-1 leading-snug">
                    JS function body. Receives <code class="font-mono">data</code> (last iteration's trials). Return <code class="font-mono">true</code> to repeat this block.
                  </p>
                </div>
              </form>
            </div>
          <% else %>
            <%= if @selected_trial do %>
              <% schema = @registry[@selected_trial.plugin] %>
              <% params = sorted_params(schema["parameters"] || %{}) %>

              <p class="text-xs font-semibold uppercase tracking-wider opacity-50 shrink-0">
                Configure
              </p>
              <p class="text-sm font-medium text-primary shrink-0 -mt-1">{@selected_trial.plugin}</p>

              <div>
                <form
                  phx-change="config_changed"
                  id={"config-form-#{@selected_trial.id}"}
                  class="space-y-5"
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
                      trial_id={@selected_trial.id}
                    />
                  <% end %>

                  <div class="divider text-xs my-1">Identification</div>

                  <div class="form-control">
                    <p class="text-sm font-medium leading-tight">Tag</p>
                    <p class="text-xs opacity-40 mt-0.5 mb-1">data.tag</p>
                    <input
                      type="text"
                      class="input input-bordered input-sm font-mono w-full"
                      name="config[data_tag]"
                      value={@selected_trial.config["data_tag"] || ""}
                      placeholder="e.g. screening-question"
                      phx-debounce="300"
                    />
                    <p class="text-xs opacity-50 mt-1 leading-snug">
                      Optional identifier. Filter this trial's response with
                      <code class="font-mono">jsPsych.data.get().filter(&#123; tag: "your-tag" &#125;)</code>.
                    </p>
                  </div>
                </form>

                <div class="divider text-xs mt-3 mb-2">Extensions</div>

                <div class="space-y-3 pb-4">
                  <%= for ext <- available_extensions() do %>
                    <% ext_cfg = Map.get(@selected_trial.extensions || %{}, ext.name, %{}) %>
                    <% enabled = Map.get(ext_cfg, "enabled", false) %>

                    <div class="flex items-start gap-2">
                      <input
                        type="checkbox"
                        class="checkbox checkbox-xs mt-1 shrink-0"
                        checked={enabled}
                        phx-click="toggle_extension"
                        phx-value-ext={ext.name}
                      />
                      <div class="flex-1 min-w-0">
                        <p class="text-xs font-medium">{ext.label}</p>
                        <p class="text-xs opacity-50 leading-tight">{ext.description}</p>

                        <%= if enabled do %>
                          <% buttons = Map.get(ext_cfg, "buttons", default_tsb_buttons()) %>
                          <div class="mt-2 space-y-2">
                            <%= for {btn, idx} <- Enum.with_index(buttons) do %>
                              <div class="border border-base-content/10 rounded p-2 space-y-1 bg-base-100">
                                <div class="flex items-center justify-between">
                                  <span class="text-xs font-medium opacity-60">Button {idx + 1}</span>
                                  <button
                                    class="btn btn-xs btn-ghost text-error px-1"
                                    phx-click="remove_tsb_button"
                                    phx-value-ext={ext.name}
                                    phx-value-index={idx}
                                    type="button"
                                  >✕</button>
                                </div>
                                <form
                                  phx-change="tsb_button_changed"
                                  id={"tsb-btn-#{@selected_trial.id}-#{idx}"}
                                  class="space-y-1"
                                >
                                  <input type="hidden" name="ext" value={ext.name} />
                                  <input type="hidden" name="index" value={idx} />
                                  <div class="flex items-center gap-2">
                                    <label class="text-xs opacity-60 w-12 shrink-0">Zone</label>
                                    <select
                                      class="select select-bordered select-xs flex-1"
                                      name="button[preset]"
                                    >
                                      <%= for {val, lbl} <- @tsb_presets do %>
                                        <option value={val} selected={Map.get(btn, "preset", "left") == val}>
                                          {lbl}
                                        </option>
                                      <% end %>
                                    </select>
                                  </div>
                                  <div class="flex items-center gap-2">
                                    <label class="text-xs opacity-60 w-12 shrink-0">Key</label>
                                    <input
                                      type="text"
                                      class="input input-bordered input-xs w-12 font-mono"
                                      name="button[key]"
                                      value={Map.get(btn, "key", "e")}
                                      maxlength="10"
                                    />
                                  </div>
                                  <div class="flex items-center gap-2">
                                    <label class="text-xs opacity-60 w-12 shrink-0">Label</label>
                                    <input
                                      type="text"
                                      class="input input-bordered input-xs flex-1"
                                      name="button[label]"
                                      value={Map.get(btn, "label", "")}
                                    />
                                  </div>
                                  <div class="flex items-center gap-2">
                                    <label class="text-xs opacity-60 w-12 shrink-0">Color</label>
                                    <input
                                      type="color"
                                      class="w-8 h-6 rounded cursor-pointer border border-base-300"
                                      name="button[color]"
                                      value={if Map.get(btn, "color", "") == "", do: "#999999", else: btn["color"]}
                                    />
                                  </div>
                                </form>
                              </div>
                            <% end %>

                            <button
                              class="btn btn-xs btn-outline w-full"
                              phx-click="add_tsb_button"
                              phx-value-ext={ext.name}
                              type="button"
                            >
                              + Add button
                            </button>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% else %>
              <p class="text-xs font-semibold uppercase tracking-wider opacity-50">Configure</p>
              <p class="text-sm opacity-40 mt-2">Click a trial block to configure it.</p>
            <% end %>
          <% end %>
          <% end %>
        </div>

        <%!-- Column 3: Phone preview --%>
        <div
          :if={@show_preview && @study_id}
          class="border-l border-base-300 pl-4 flex flex-col gap-3"
        >
          <div class="flex items-center justify-between shrink-0">
            <p class="text-xs font-semibold uppercase tracking-wider opacity-50">Live Preview</p>
            <button
              class="btn btn-xs btn-ghost"
              phx-click="reload_preview"
              type="button"
              title="Reload preview"
            >
              ↺ Reload
            </button>
          </div>

          <div class="flex justify-center items-start">
            <div class="mockup-phone shrink-0">
              <div class="camera"></div>
              <div class="display" style="width:300px; aspect-ratio:9/16;">
                <iframe
                  src={"/study/#{@study_id}?preview=true&k=#{@preview_key}"}
                  style="width:100%;height:100%;border:none;"
                  title="Study preview"
                />
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>
    </Layouts.app>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".TipTap">
      import { Editor } from "@tiptap/core"
      import StarterKit from "@tiptap/starter-kit"
      import Link from "@tiptap/extension-link"
      import Image from "@tiptap/extension-image"

      export default {
        mounted() {
          const fieldName = this.el.dataset.fieldName
          const initialValue = this.el.dataset.value || ""

          // Hidden textarea carries the value in form serialization
          this.textarea = document.createElement("textarea")
          this.textarea.name = fieldName
          this.textarea.style.cssText = "display:none"
          this.textarea.value = initialValue
          this.el.appendChild(this.textarea)

          // Toolbar
          this.toolbar = document.createElement("div")
          this.toolbar.className = "flex gap-1 flex-wrap p-1 border-b border-base-300 bg-base-200 rounded-t"
          this.el.appendChild(this.toolbar)

          // Editor mount point
          const editorEl = document.createElement("div")
          this.el.appendChild(editorEl)

          const toolbarDefs = [
            { label: "B",       title: "Bold",          style: "font-bold", cmd: () => this.editor.chain().focus().toggleBold().run(),                   active: () => this.editor.isActive("bold") },
            { label: "I",       title: "Italic",        style: "italic",    cmd: () => this.editor.chain().focus().toggleItalic().run(),                 active: () => this.editor.isActive("italic") },
            { label: "H1",      title: "Heading 1",     style: "",          cmd: () => this.editor.chain().focus().toggleHeading({ level: 1 }).run(),    active: () => this.editor.isActive("heading", { level: 1 }) },
            { label: "H2",      title: "Heading 2",     style: "",          cmd: () => this.editor.chain().focus().toggleHeading({ level: 2 }).run(),    active: () => this.editor.isActive("heading", { level: 2 }) },
            { label: "• List",  title: "Bullet list",   style: "",          cmd: () => this.editor.chain().focus().toggleBulletList().run(),             active: () => this.editor.isActive("bulletList") },
            { label: "1. List", title: "Ordered list",  style: "",          cmd: () => this.editor.chain().focus().toggleOrderedList().run(),            active: () => this.editor.isActive("orderedList") },
            { label: "🔗",      title: "Link",          style: "",          cmd: () => this.setLink(),                                                   active: () => this.editor.isActive("link") },
            { label: "🖼",      title: "Image",         style: "",          cmd: () => this.insertImage(),                                               active: () => false },
          ]

          toolbarDefs.forEach(({ label, title, style, cmd }) => {
            const btn = document.createElement("button")
            btn.type = "button"
            btn.title = title
            btn.textContent = label
            btn.className = `btn btn-xs btn-ghost ${style}`
            btn.addEventListener("mousedown", e => { e.preventDefault(); cmd() })
            this.toolbar.appendChild(btn)
          })

          this.editor = new Editor({
            element: editorEl,
            extensions: [
              StarterKit,
              Link.configure({ openOnClick: false }),
              Image,
            ],
            content: initialValue,
            editorProps: { attributes: { class: "outline-none" } },
            onUpdate: ({ editor }) => {
              this.textarea.value = editor.getHTML()
              this.textarea.dispatchEvent(new Event("input", { bubbles: true }))
            },
            onTransaction: () => {
              const btns = this.toolbar.querySelectorAll("button")
              toolbarDefs.forEach(({ active }, i) => {
                btns[i]?.classList.toggle("btn-active", active())
              })
            },
          })
        },

        setLink() {
          const prev = this.editor.getAttributes("link").href || ""
          const url = window.prompt("Link URL", prev)
          if (url === null) return
          if (url === "") {
            this.editor.chain().focus().unsetLink().run()
          } else {
            this.editor.chain().focus().setLink({ href: url }).run()
          }
        },

        insertImage() {
          const url = window.prompt("Image URL")
          if (url) this.editor.chain().focus().setImage({ src: url }).run()
        },

        updated() {
          const newVal = this.el.dataset.value || ""
          if (this.editor && newVal !== this.editor.getHTML()) {
            this.editor.commands.setContent(newVal, false)
          }
        },

        destroyed() {
          this.editor?.destroy()
        }
      }
    </script>

    """
  end

  # ── Function Components ────────────────────────────────────────────────────

  attr :node, :map, required: true
  attr :position, :integer, required: true
  attr :selected_id, :integer, default: nil

  defp node_block(%{node: %{node_type: "template_group"}} = assigns) do
    ~H"""
    <div class="space-y-1">
      <div class={"card shadow-sm border-2 transition-colors " <>
        if(@selected_id == @node.id,
          do: "bg-accent/10 border-accent",
          else: "bg-base-300 border-transparent"
        )}>
        <div class="flex items-center gap-2 p-3">
          <button
            class="btn btn-xs btn-ghost px-1 shrink-0"
            phx-click={
              JS.toggle(to: "#tpl-children-#{@node.id}")
              |> JS.toggle_class("rotate-180", to: "#tpl-chevron-#{@node.id}")
            }
            type="button"
            title="Collapse/expand"
          >
            <span id={"tpl-chevron-#{@node.id}"} class="inline-block transition-transform">▾</span>
          </button>
          <div
            class="flex items-center gap-2 flex-1 min-w-0 cursor-pointer"
            phx-click="select_trial"
            phx-value-id={@node.id}
          >
            <span class="badge badge-accent shrink-0">TPL</span>
            <span class="text-sm font-medium truncate">
              {@node.config["template_name"] || "Template"}
            </span>
            <span class="text-xs opacity-40">({length(@node.children)} blocks)</span>
          </div>
          <div class="flex items-center gap-0.5 shrink-0">
            <button
              class="btn btn-xs btn-ghost px-1"
              phx-click="move_trial_up"
              phx-value-id={@node.id}
              type="button"
              title="Move up"
            >↑</button>
            <button
              class="btn btn-xs btn-ghost px-1"
              phx-click="move_trial_down"
              phx-value-id={@node.id}
              type="button"
              title="Move down"
            >↓</button>
            <button
              class="btn btn-xs btn-ghost px-1 text-error"
              phx-click="remove_trial"
              phx-value-id={@node.id}
              type="button"
              title="Remove"
            >✕</button>
          </div>
        </div>
      </div>

      <div id={"tpl-children-#{@node.id}"} class="ml-4 pl-3 border-l-2 border-accent/30 space-y-1">
        <%= for {child, child_pos} <- Enum.with_index(@node.children, 1) do %>
          <.node_block node={child} position={child_pos} selected_id={@selected_id} />
        <% end %>
      </div>
    </div>
    """
  end

  defp node_block(%{node: %{node_type: "timeline"}} = assigns) do
    ~H"""
    <div class="space-y-1">
      <div class={"card shadow-sm border-2 transition-colors " <>
        if(@selected_id == @node.id,
          do: "bg-secondary/10 border-secondary",
          else: "bg-base-300 border-transparent"
        )}>
        <div class="flex items-center gap-2 p-3">
          <button
            class="btn btn-xs btn-ghost px-1 shrink-0"
            phx-click={
              JS.toggle(to: "#tl-children-#{@node.id}")
              |> JS.toggle_class("rotate-180", to: "#tl-chevron-#{@node.id}")
            }
            type="button"
            title="Collapse/expand"
          >
            <span id={"tl-chevron-#{@node.id}"} class="inline-block transition-transform">▾</span>
          </button>
          <div
            class="flex items-center gap-2 flex-1 min-w-0 cursor-pointer"
            phx-click="select_trial"
            phx-value-id={@node.id}
          >
            <span class="badge badge-secondary shrink-0">TL</span>
            <span class="text-sm font-medium truncate">Timeline Group</span>
            <span class="text-xs opacity-40">({length(@node.children)} trials)</span>
          </div>
          <div class="flex items-center gap-0.5 shrink-0">
            <button
              class="btn btn-xs btn-ghost px-1"
              phx-click="move_trial_up"
              phx-value-id={@node.id}
              type="button"
              title="Move up"
            >↑</button>
            <button
              class="btn btn-xs btn-ghost px-1"
              phx-click="move_trial_down"
              phx-value-id={@node.id}
              type="button"
              title="Move down"
            >↓</button>
            <button
              class="btn btn-xs btn-ghost px-1 text-error"
              phx-click="remove_trial"
              phx-value-id={@node.id}
              type="button"
              title="Remove"
            >✕</button>
          </div>
        </div>
      </div>

      <div id={"tl-children-#{@node.id}"} class="ml-4 pl-3 border-l-2 border-secondary/30 space-y-1">
        <p :if={@node.children == []} class="text-xs opacity-40 py-1 italic">
          Select this group then click a plugin to add trials here.
        </p>
        <%= for {child, child_pos} <- Enum.with_index(@node.children, 1) do %>
          <.node_block node={child} position={child_pos} selected_id={@selected_id} />
        <% end %>
      </div>
    </div>
    """
  end

  defp node_block(assigns) do
    ~H"""
    <div class={"card shadow-sm border-2 transition-colors " <>
      if(@selected_id == @node.id,
        do: "bg-primary/10 border-primary",
        else: "bg-base-200 border-transparent"
      )}>
      <div class="flex items-center gap-2 p-3">
        <div
          class="flex items-center gap-2 flex-1 min-w-0 cursor-pointer"
          phx-click="select_trial"
          phx-value-id={@node.id}
        >
          <span class="badge badge-neutral shrink-0">#{@position}</span>
          <span class="text-sm font-medium truncate">{@node.plugin}</span>
        </div>
        <div class="flex items-center gap-0.5 shrink-0">
          <button
            class="btn btn-xs btn-ghost px-1"
            phx-click="move_trial_up"
            phx-value-id={@node.id}
            type="button"
            title="Move up"
          >
            ↑
          </button>
          <button
            class="btn btn-xs btn-ghost px-1"
            phx-click="move_trial_down"
            phx-value-id={@node.id}
            type="button"
            title="Move down"
          >
            ↓
          </button>
          <button
            class="btn btn-xs btn-ghost px-1 text-error"
            phx-click="remove_trial"
            phx-value-id={@node.id}
            type="button"
            title="Remove"
          >
            ✕
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :param, :string, required: true
  attr :prefix, :string, default: "config"
  attr :spec, :map, required: true
  attr :kind, :atom, required: true
  attr :value, :any, default: nil
  attr :trial_id, :any, default: nil

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
    <div>
      <p class="text-sm font-medium leading-tight mb-1">{@param}</p>
      <div class="flex items-center gap-2">
        <input type="hidden" name={"#{@prefix}[#{@param}]"} value="false" />
        <input
          type="checkbox"
          class="checkbox checkbox-sm"
          name={"#{@prefix}[#{@param}]"}
          value="true"
          checked={@value == true or @value == "true"}
        />
        <span class="text-xs opacity-40">BOOL</span>
      </div>
    </div>
    """
  end

  defp param_field(%{kind: :number} = assigns) do
    ~H"""
    <div class="form-control">
      <p class="text-sm font-medium leading-tight">{@param}</p>
      <p class="text-xs opacity-40 mt-0.5 mb-1">{@spec["type"]}</p>
      <input
        type="number"
        class="input input-bordered input-sm w-full"
        name={"#{@prefix}[#{@param}]"}
        value={@value || ""}
        step={if @spec["type"] == "FLOAT", do: "0.01", else: "1"}
        placeholder={to_string(@spec["default"] || "")}
      />
    </div>
    """
  end

  defp param_field(%{kind: :html} = assigns) do
    safe_id = String.replace("tiptap-#{assigns.prefix}-#{assigns.param}", ~r/[\[\]]/, "_")
    assigns = assign(assigns, safe_id: safe_id)

    ~H"""
    <div class="form-control">
      <p class="text-sm font-medium leading-tight">{@param}</p>
      <p class="text-xs opacity-40 mt-0.5 mb-1">HTML</p>
      <div
        id={@safe_id}
        phx-hook=".TipTap"
        phx-update="ignore"
        data-field-name={"#{@prefix}[#{@param}]"}
        data-value={@value || ""}
        class="tiptap-editor rounded border border-base-300"
      ></div>
    </div>
    """
  end

  defp param_field(%{kind: :json, param: "survey_json"} = assigns) do
    field_name = "#{assigns.prefix}[#{assigns.param}]"
    assigns = assign(assigns, field_name: field_name)

    ~H"""
    <div class="form-control">
      <label class="label py-1">
        <span class="label-text">survey_json</span>
        <span class="label-text-alt opacity-50">Survey builder</span>
      </label>
      <.live_component
        module={SurveyBuilderComponent}
        id={"survey-builder-#{@trial_id || @prefix}"}
        value={@value}
        field_name={@field_name}
      />
    </div>
    """
  end

  defp param_field(%{kind: :json} = assigns) do
    json_value =
      case assigns.value do
        nil -> ""
        "" -> ""
        val when is_map(val) -> Jason.encode!(val, pretty: true)
        val when is_binary(val) -> val
      end

    assigns = assign(assigns, json_value: json_value)

    ~H"""
    <div class="form-control">
      <label class="label py-1">
        <span class="label-text">{@param}</span>
        <span class="label-text-alt opacity-50">JSON</span>
      </label>
      <textarea
        class="textarea textarea-bordered textarea-sm font-mono text-xs"
        name={"#{@prefix}[#{@param}]"}
        rows="10"
        placeholder={"{\n  \"elements\": []\n}"}
      >{@json_value}</textarea>
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
      <p class="text-sm font-medium leading-tight">{@param}</p>
      <p class="text-xs opacity-40 mt-0.5 mb-1">
        {@spec["type"]}{if @spec["array"], do: "[]", else: ""}
      </p>
      <input
        type="text"
        class="input input-bordered input-sm w-full"
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
