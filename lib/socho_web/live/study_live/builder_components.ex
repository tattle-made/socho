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
    <div class="space-y-1" data-node-id={@node.id}>
      <div class={"card shadow-sm border-2 transition-colors " <>
        if(@selected_id == @node.id,
          do: "bg-accent/10 border-accent",
          else: "bg-base-300 border-transparent"
        )}>
        <div class="flex items-center gap-1 p-3">
          <span class="drag-handle cursor-grab text-base-content/30 hover:text-base-content px-0.5 shrink-0 select-none">⠿</span>
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
          <span class="badge badge-accent shrink-0">TPL</span>
          <div
            class="flex items-center gap-1 flex-1 min-w-0 cursor-pointer"
            phx-click="select_trial"
            phx-value-id={@node.id}
          >
            <form phx-change="rename_node" class="flex-1 min-w-0">
              <input type="hidden" name="node_id" value={to_string(@node.id)} />
              <input
                type="text"
                class="input input-ghost input-xs w-full text-sm font-medium px-1"
                name="label"
                value={@node.config["label"] || ""}
                placeholder={@node.config["template_name"] || "Template"}
                phx-debounce="500"
              />
            </form>
            <span class="text-xs opacity-40 shrink-0">({length(@node.children)} blocks)</span>
          </div>
          <.node_menu node={@node} />
        </div>
      </div>

      <div id={"tpl-children-#{@node.id}"} phx-hook="Sortable" class="ml-4 pl-3 border-l-2 border-accent/30 space-y-1">
        <%= for {child, child_pos} <- Enum.with_index(@node.children, 1) do %>
          <.node_block node={child} position={child_pos} selected_id={@selected_id} />
        <% end %>
      </div>
    </div>
    """
  end

  def node_block(%{node: %{node_type: "timeline"}} = assigns) do
    ~H"""
    <div class="space-y-1" data-node-id={@node.id}>
      <div class={"card shadow-sm border-2 transition-colors " <>
        if(@selected_id == @node.id,
          do: "bg-secondary/10 border-secondary",
          else: "bg-base-300 border-transparent"
        )}>
        <div class="flex items-center gap-1 p-3">
          <span class="drag-handle cursor-grab text-base-content/30 hover:text-base-content px-0.5 shrink-0 select-none">⠿</span>
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
          <span class="badge badge-secondary shrink-0">TL</span>
          <div
            class="flex items-center gap-1 flex-1 min-w-0 cursor-pointer"
            phx-click="select_trial"
            phx-value-id={@node.id}
          >
            <form phx-change="rename_node" class="flex-1 min-w-0">
              <input type="hidden" name="node_id" value={to_string(@node.id)} />
              <input
                type="text"
                class="input input-ghost input-xs w-full text-sm font-medium px-1"
                name="label"
                value={@node.config["label"] || ""}
                placeholder="Timeline"
                phx-debounce="500"
              />
            </form>
            <span class="text-xs opacity-40 shrink-0">({length(@node.children)} trials)</span>
          </div>
          <.node_menu node={@node} />
        </div>
      </div>

      <div id={"tl-children-#{@node.id}"} phx-hook="Sortable" class="ml-4 pl-3 border-l-2 border-secondary/30 space-y-1">
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
      )} data-node-id={@node.id}>
      <div class="flex items-center gap-1 p-3">
        <span class="drag-handle cursor-grab text-base-content/30 hover:text-base-content px-0.5 shrink-0 select-none">⠿</span>
        <span class="badge badge-neutral shrink-0">#{@position}</span>
        <div
          class="flex items-center gap-1 flex-1 min-w-0 cursor-pointer"
          phx-click="select_trial"
          phx-value-id={@node.id}
        >
          <form phx-change="rename_node" class="flex-1 min-w-0">
            <input type="hidden" name="node_id" value={to_string(@node.id)} />
            <input
              type="text"
              class="input input-ghost input-xs w-full text-sm font-medium px-1"
              name="label"
              value={@node.config["label"] || ""}
              placeholder={@node.plugin}
              phx-debounce="500"
            />
          </form>
        </div>
        <.node_menu node={@node} />
      </div>
    </div>
    """
  end

  attr :node, :map, required: true

  defp node_menu(assigns) do
    ~H"""
    <div class="dropdown dropdown-end shrink-0">
      <button tabindex="0" type="button" class="btn btn-xs btn-ghost px-1" title="Actions">⋯</button>
      <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box shadow-lg z-10 w-44 p-1 text-sm">
        <li>
          <button type="button" phx-click="move_trial_up" phx-value-id={@node.id} class="flex gap-2">
            <span>↑</span> Move up
          </button>
        </li>
        <li>
          <button type="button" phx-click="move_trial_down" phx-value-id={@node.id} class="flex gap-2">
            <span>↓</span> Move down
          </button>
        </li>
        <li>
          <button type="button" phx-click="duplicate_trial" phx-value-id={@node.id} class="flex gap-2">
            <span>⧉</span> Duplicate
          </button>
        </li>
        <li>
          <button type="button" phx-click="remove_trial" phx-value-id={@node.id} class="flex gap-2 text-error">
            <span>✕</span> Delete
          </button>
        </li>
      </ul>
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
  attr :data_tags, :list, default: []

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
    display_value = case assigns.value do
      [first | _] -> first
      v -> v || ""
    end
    assigns = assign(assigns, safe_id: safe_id, display_value: display_value)

    ~H"""
    <div class="form-control">
      <p class="text-sm font-medium leading-tight">{@param}</p>
      <p class="text-xs opacity-40 mt-0.5 mb-1">HTML</p>
      <div
        id={@safe_id}
        phx-hook=".TipTap"
        phx-update="ignore"
        data-field-name={"#{@prefix}[#{@param}]"}
        data-value={@display_value}
        class="tiptap-editor rounded border border-base-300"
      ></div>
    </div>

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
        data_tags={@data_tags}
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
