defmodule SochoWeb.StudyLive.BuilderComponents do
  use SochoWeb, :html

  alias SochoWeb.StudyLive.SurveyBuilderComponent

  # ── Input kind classifier ──────────────────────────────────────────────────

  def input_kind(%{"type" => "BOOL"}), do: :bool
  def input_kind(%{"type" => "INT"}), do: :number
  def input_kind(%{"type" => "FLOAT"}), do: :number
  def input_kind(%{"type" => "HTML_STRING"}), do: :html
  def input_kind(%{"type" => "COMPLEX", "array" => true}), do: :complex_array
  def input_kind(%{"type" => "OBJECT"}), do: :json
  def input_kind(%{"type" => "FUNCTION"}), do: :skip
  def input_kind(%{"type" => "TIMELINE"}), do: :skip
  def input_kind(_), do: :text

  # ── Node block components ──────────────────────────────────────────────────

  attr :node, :map, required: true
  attr :position, :integer, required: true
  attr :selected_id, :integer, default: nil

  def node_block(%{node: %{node_type: "template_group"}} = assigns) do
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

  def node_block(%{node: %{node_type: "timeline"}} = assigns) do
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

  def node_block(assigns) do
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

  # ── Param field components ─────────────────────────────────────────────────

  attr :param, :string, required: true
  attr :prefix, :string, default: "config"
  attr :spec, :map, required: true
  attr :kind, :atom, required: true
  attr :value, :any, default: nil
  attr :trial_id, :any, default: nil

  def param_field(%{kind: :complex_array} = assigns) do
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

  def param_field(%{kind: :bool} = assigns) do
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

  def param_field(%{kind: :number} = assigns) do
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

  def param_field(%{kind: :html} = assigns) do
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

  def param_field(%{kind: :json, param: "survey_json"} = assigns) do
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

  def param_field(%{kind: :json} = assigns) do
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

  def param_field(assigns) do
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
