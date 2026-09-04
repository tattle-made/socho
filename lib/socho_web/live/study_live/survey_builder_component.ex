defmodule SochoWeb.StudyLive.SurveyBuilderComponent do
  use SochoWeb, :live_component

  @question_types [
    {"html", "HTML content"},
    {"text", "Short text"},
    {"number", "Number"},
    {"comment", "Long text"},
    {"radiogroup", "Single choice"},
    {"checkbox", "Multiple choice"},
    {"dropdown", "Dropdown"},
    {"rating", "Rating scale"},
    {"boolean", "Yes / No"},
    {"ranking", "Ranking"},
    {"matrix_multiselect", "Multi-Select Matrix"},
    {"dynamic_matrix", "Dynamic Multi Matrix Select"}
  ]

  @choice_types ["radiogroup", "checkbox", "dropdown", "ranking"]
  @matrix_types ["matrix_multiselect", "dynamic_matrix"]

  @impl true
  def update(%{value: value, field_name: field_name} = assigns, socket) do
    data_tags = assigns[:data_tags] || []

    socket =
      if Map.has_key?(socket.assigns, :questions) do
        assign(socket, id: assigns.id, field_name: field_name, data_tags: data_tags)
      else
        parsed = parse_survey_json(value)

        socket
        |> assign(
          id: assigns.id,
          field_name: field_name,
          questions: parsed.questions,
          complete_text: parsed.complete_text,
          question_types: @question_types,
          choice_types: @choice_types,
          matrix_types: @matrix_types,
          data_tags: data_tags
        )
        |> tap(&notify_parent/1)
      end

    {:ok, socket}
  end

  # ── Event handlers ──────────────────────────────────────────────────────────

  @impl true
  def handle_event("sq_add_question", _params, socket) do
    n = length(socket.assigns.questions) + 1

    new_q = %{
      "type" => "text",
      "name" => "question#{n}",
      "title" => "",
      "html" => "",
      "isRequired" => false,
      "choices" => [],
      "minValue" => "",
      "maxValue" => "",
      "inputType" => "free",
      "minWords" => "",
      "maxWords" => "",
      "rows" => [],
      "columns" => [],
      "cellType" => "checkbox",
      "dyn_source_tag" => "",
      "dyn_source_question" => "",
      "dyn_source_columns" => [],
      "static_columns" => [],
      "randomize_rows" => false
    }

    socket = update(socket, :questions, fn qs -> qs ++ [new_q] end)
    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_remove_question", %{"index" => idx}, socket) do
    idx = String.to_integer(idx)
    socket = update(socket, :questions, fn qs -> List.delete_at(qs, idx) end)
    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_set_type", %{"index" => idx, "type" => type_val}, socket) do
    idx = String.to_integer(idx)
    socket = update(socket, :questions, fn qs -> List.update_at(qs, idx, fn q -> Map.put(q, "type", type_val) end) end)
    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_update_field", %{"index" => idx, "field" => field, "value" => val}, socket) do
    idx = String.to_integer(idx)
    socket = update(socket, :questions, fn qs -> List.update_at(qs, idx, fn q -> Map.put(q, field, val) end) end)
    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_update_dyn_source_tag", %{"index" => idx, "value" => tag}, socket) do
    idx = String.to_integer(idx)
    socket = update(socket, :questions, fn qs ->
      List.update_at(qs, idx, fn q ->
        q
        |> Map.put("dyn_source_tag", tag)
        |> Map.put("dyn_source_question", "")
        |> Map.put("dyn_source_columns", [])
      end)
    end)
    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_update_dyn_source_question", %{"index" => idx, "value" => question_name}, socket) do
    idx = String.to_integer(idx)
    socket = update(socket, :questions, fn qs ->
      List.update_at(qs, idx, fn q ->
        tag = q["dyn_source_tag"]
        tag_meta = Enum.find(socket.assigns.data_tags, fn dt -> dt["tag"] == tag end)
        columns =
          if tag_meta do
            qs_meta = tag_meta["questions"] || []
            found = Enum.find(qs_meta, fn qq -> qq["name"] == question_name end)
            if found, do: found["columns"] || [], else: []
          else
            []
          end
        q
        |> Map.put("dyn_source_question", question_name)
        |> Map.put("dyn_source_columns", columns)
      end)
    end)
    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_toggle_required", %{"index" => idx} = params, socket) do
    idx = String.to_integer(idx)
    is_required = Map.has_key?(params, "required")

    socket =
      update(socket, :questions, fn qs ->
        List.update_at(qs, idx, fn q -> Map.put(q, "isRequired", is_required) end)
      end)

    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_toggle_randomize_rows", %{"index" => idx} = params, socket) do
    idx = String.to_integer(idx)
    randomize = Map.has_key?(params, "randomize_rows")

    socket =
      update(socket, :questions, fn qs ->
        List.update_at(qs, idx, fn q -> Map.put(q, "randomize_rows", randomize) end)
      end)

    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_add_choice", %{"index" => idx}, socket) do
    idx = String.to_integer(idx)

    socket =
      update(socket, :questions, fn qs ->
        List.update_at(qs, idx, fn q -> Map.update(q, "choices", [""], fn cs -> cs ++ [""] end) end)
      end)

    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_remove_choice", %{"q" => q_i, "c" => c_i}, socket) do
    q_i = String.to_integer(q_i)
    c_i = String.to_integer(c_i)

    socket =
      update(socket, :questions, fn qs ->
        List.update_at(qs, q_i, fn q -> Map.update(q, "choices", [], fn cs -> List.delete_at(cs, c_i) end) end)
      end)

    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_update_choice", %{"q" => q_i, "c" => c_i, "value" => val}, socket) do
    q_i = String.to_integer(q_i)
    c_i = String.to_integer(c_i)

    socket =
      update(socket, :questions, fn qs ->
        List.update_at(qs, q_i, fn q -> Map.update(q, "choices", [], fn cs -> List.replace_at(cs, c_i, val) end) end)
      end)

    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_add_row", %{"index" => idx}, socket) do
    idx = String.to_integer(idx)
    socket = update(socket, :questions, fn qs ->
      List.update_at(qs, idx, fn q ->
        Map.update(q, "rows", [new_row()], fn rs -> rs ++ [new_row()] end)
      end)
    end)
    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_remove_row", %{"q" => q_i, "r" => r_i}, socket) do
    q_i = String.to_integer(q_i)
    r_i = String.to_integer(r_i)
    socket = update(socket, :questions, fn qs ->
      List.update_at(qs, q_i, fn q -> Map.update(q, "rows", [], fn rs -> List.delete_at(rs, r_i) end) end)
    end)
    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_update_row", %{"q" => q_i, "r" => r_i, "value" => val}, socket) do
    q_i = String.to_integer(q_i)
    r_i = String.to_integer(r_i)
    socket = update(socket, :questions, fn qs ->
      List.update_at(qs, q_i, fn q ->
        Map.update(q, "rows", [], fn rs ->
          List.update_at(rs, r_i, fn row -> Map.put(normalize_row(row), "text", val) end)
        end)
      end)
    end)
    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_toggle_row_reversed", %{"q" => q_i, "r" => r_i} = params, socket) do
    q_i = String.to_integer(q_i)
    r_i = String.to_integer(r_i)
    reversed = Map.has_key?(params, "reversed")
    socket = update(socket, :questions, fn qs ->
      List.update_at(qs, q_i, fn q ->
        Map.update(q, "rows", [], fn rs ->
          List.update_at(rs, r_i, fn row -> Map.put(normalize_row(row), "reversed", reversed) end)
        end)
      end)
    end)
    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_add_column", %{"index" => idx}, socket) do
    idx = String.to_integer(idx)
    socket = update(socket, :questions, fn qs ->
      List.update_at(qs, idx, fn q -> Map.update(q, "columns", [""], fn cs -> cs ++ [""] end) end)
    end)
    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_remove_column", %{"q" => q_i, "c" => c_i}, socket) do
    q_i = String.to_integer(q_i)
    c_i = String.to_integer(c_i)
    socket = update(socket, :questions, fn qs ->
      List.update_at(qs, q_i, fn q -> Map.update(q, "columns", [], fn cs -> List.delete_at(cs, c_i) end) end)
    end)
    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_update_column", %{"q" => q_i, "c" => c_i, "value" => val}, socket) do
    q_i = String.to_integer(q_i)
    c_i = String.to_integer(c_i)
    socket = update(socket, :questions, fn qs ->
      List.update_at(qs, q_i, fn q -> Map.update(q, "columns", [], fn cs -> List.replace_at(cs, c_i, val) end) end)
    end)
    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_add_static_column", %{"index" => idx}, socket) do
    idx = String.to_integer(idx)
    socket = update(socket, :questions, fn qs ->
      List.update_at(qs, idx, fn q -> Map.update(q, "static_columns", [""], fn cs -> cs ++ [""] end) end)
    end)
    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_remove_static_column", %{"q" => q_i, "c" => c_i}, socket) do
    q_i = String.to_integer(q_i)
    c_i = String.to_integer(c_i)
    socket = update(socket, :questions, fn qs ->
      List.update_at(qs, q_i, fn q -> Map.update(q, "static_columns", [], fn cs -> List.delete_at(cs, c_i) end) end)
    end)
    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_update_static_column", %{"q" => q_i, "c" => c_i, "value" => val}, socket) do
    q_i = String.to_integer(q_i)
    c_i = String.to_integer(c_i)
    socket = update(socket, :questions, fn qs ->
      List.update_at(qs, q_i, fn q -> Map.update(q, "static_columns", [], fn cs -> List.replace_at(cs, c_i, val) end) end)
    end)
    notify_parent(socket)
    {:noreply, socket}
  end

  def handle_event("sq_set_complete_text", %{"value" => val}, socket) do
    socket = assign(socket, :complete_text, val)
    notify_parent(socket)
    {:noreply, socket}
  end

  # ── Render ──────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="space-y-3">
      <%= for {q, idx} <- Enum.with_index(@questions) do %>
        <div class="border border-base-300 rounded-lg p-3 space-y-2">
          <div class="flex justify-between items-center">
            <span class="text-xs font-semibold opacity-50">Question {idx + 1}</span>
            <button
              type="button"
              class="btn btn-xs btn-ghost text-error"
              phx-click="sq_remove_question"
              phx-value-index={idx}
              phx-target={"##{@id}"}
            >
              ✕
            </button>
          </div>

          <div class="form-control">
            <label class="label py-0"><span class="label-text text-xs">Type</span></label>
            <div class="flex flex-wrap gap-1 mt-1">
              <%= for {type_val, type_label} <- @question_types do %>
                <button
                  type="button"
                  class={"btn btn-xs #{if q["type"] == type_val, do: "btn-neutral", else: "btn-outline"}"}
                  phx-click="sq_set_type"
                  phx-value-index={idx}
                  phx-value-type={type_val}
                  phx-target={"##{@id}"}
                >
                  {type_label}
                </button>
              <% end %>
            </div>
          </div>

          <%= if q["type"] == "html" do %>
            <div class="form-control">
              <label class="label py-0">
                <span class="label-text text-xs">HTML content</span>
              </label>
              <div
                id={"sq-html-#{@id}-#{idx}"}
                phx-hook=".SurveyHtml"
                phx-update="ignore"
                data-index={to_string(idx)}
                data-value={q["html"] || ""}
                data-field="html"
                data-component-id={@id}
                class="tiptap-editor rounded border border-base-300"
              ></div>
            </div>
          <% else %>
            <div class="form-control">
              <label class="label py-0"><span class="label-text text-xs">Question text</span></label>
              <div
                id={"sq-title-#{@id}-#{idx}"}
                phx-hook=".SurveyHtml"
                phx-update="ignore"
                data-index={to_string(idx)}
                data-value={q["title"] || ""}
                data-field="title"
                data-component-id={@id}
                class="tiptap-editor rounded border border-base-300"
              ></div>
            </div>

            <form phx-change="sq_toggle_required" phx-target={"##{@id}"}>
              <input type="hidden" name="index" value={to_string(idx)} />
              <label class="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  name="required"
                  class="checkbox checkbox-xs"
                  checked={q["isRequired"]}
                />
                <span class="text-xs">Required</span>
              </label>
            </form>
          <% end %>

          <div class="form-control">
            <label class="label py-0"><span class="label-text text-xs">Field name</span></label>
            <input
              type="text"
              class="input input-bordered input-xs font-mono"
              value={q["name"]}
              phx-blur="sq_update_field"
              phx-value-index={idx}
              phx-value-field="name"
              phx-target={"##{@id}"}
            />
          </div>

          <%= if q["type"] == "number" do %>
            <div class="grid grid-cols-2 gap-2">
              <div class="form-control">
                <label class="label py-0"><span class="label-text text-xs">Min value</span></label>
                <input
                  type="number"
                  class="input input-bordered input-xs"
                  value={q["minValue"]}
                  phx-blur="sq_update_field"
                  phx-value-index={idx}
                  phx-value-field="minValue"
                  phx-target={"##{@id}"}
                />
              </div>
              <div class="form-control">
                <label class="label py-0"><span class="label-text text-xs">Max value</span></label>
                <input
                  type="number"
                  class="input input-bordered input-xs"
                  value={q["maxValue"]}
                  phx-blur="sq_update_field"
                  phx-value-index={idx}
                  phx-value-field="maxValue"
                  phx-target={"##{@id}"}
                />
              </div>
            </div>
          <% end %>

          <%= if q["type"] == "text" do %>
            <div class="form-control">
              <label class="label py-0"><span class="label-text text-xs">Input type</span></label>
              <form phx-change="sq_update_field" phx-target={"##{@id}"}>
                <input type="hidden" name="index" value={idx} />
                <input type="hidden" name="field" value="inputType" />
                <select name="value" class="select select-bordered select-xs w-full">
                  <option value="free" selected={q["inputType"] in [nil, "", "free"]}>Free text</option>
                  <option value="email" selected={q["inputType"] == "email"}>Email</option>
                  <option value="phone" selected={q["inputType"] == "phone"}>Phone number</option>
                </select>
              </form>
            </div>
            <%= if q["inputType"] in [nil, "", "free"] do %>
              <div class="grid grid-cols-2 gap-2">
                <div class="form-control">
                  <label class="label py-0"><span class="label-text text-xs">Min words</span></label>
                  <input
                    type="number"
                    min="0"
                    class="input input-bordered input-xs"
                    value={q["minWords"] || ""}
                    phx-blur="sq_update_field"
                    phx-value-index={idx}
                    phx-value-field="minWords"
                    phx-target={"##{@id}"}
                  />
                </div>
                <div class="form-control">
                  <label class="label py-0"><span class="label-text text-xs">Max words</span></label>
                  <input
                    type="number"
                    min="0"
                    class="input input-bordered input-xs"
                    value={q["maxWords"] || ""}
                    phx-blur="sq_update_field"
                    phx-value-index={idx}
                    phx-value-field="maxWords"
                    phx-target={"##{@id}"}
                  />
                </div>
              </div>
            <% end %>
          <% end %>

          <%= if q["type"] in @choice_types do %>
            <div class="space-y-1">
              <label class="label py-0"><span class="label-text text-xs">Choices</span></label>
              <%= for {choice, c_idx} <- Enum.with_index(q["choices"] || []) do %>
                <div class="flex gap-1 items-center">
                  <input
                    type="text"
                    class="input input-bordered input-xs flex-1"
                    value={choice}
                    phx-blur="sq_update_choice"
                    phx-value-q={idx}
                    phx-value-c={c_idx}
                    phx-target={"##{@id}"}
                  />
                  <button
                    type="button"
                    class="btn btn-xs btn-ghost text-error"
                    phx-click="sq_remove_choice"
                    phx-value-q={idx}
                    phx-value-c={c_idx}
                    phx-target={"##{@id}"}
                  >
                    ✕
                  </button>
                </div>
              <% end %>
              <button
                type="button"
                class="btn btn-xs btn-outline"
                phx-click="sq_add_choice"
                phx-value-index={idx}
                phx-target={"##{@id}"}
              >
                + Add choice
              </button>
            </div>
          <% end %>

          <%= if q["type"] in @matrix_types do %>
            <div class="space-y-2">
              <div class="space-y-1">
                <label class="label py-0"><span class="label-text text-xs">Rows</span></label>
                <%= for {row, r_idx} <- Enum.with_index(q["rows"] || []) do %>
                  <% row_map = normalize_row(row) %>
                  <div class="flex gap-1 items-center">
                    <div
                      phx-hook=".SurveyRowText"
                      phx-update="ignore"
                      id={"row-editor-#{idx}-#{r_idx}"}
                      data-q={idx}
                      data-r={r_idx}
                      data-component-id={@id}
                      data-value={row_map["text"]}
                      class="flex-1 relative"
                    />
                    <form phx-change="sq_toggle_row_reversed" phx-target={"##{@id}"}>
                      <input type="hidden" name="q" value={to_string(idx)} />
                      <input type="hidden" name="r" value={to_string(r_idx)} />
                      <label class="flex items-center gap-1 cursor-pointer whitespace-nowrap">
                        <input
                          type="checkbox"
                          name="reversed"
                          class="checkbox checkbox-xs"
                          checked={row_map["reversed"]}
                        />
                        <span class="text-xs">Rev</span>
                      </label>
                    </form>
                    <button
                      type="button"
                      class="btn btn-xs btn-ghost text-error"
                      phx-click="sq_remove_row"
                      phx-value-q={idx}
                      phx-value-r={r_idx}
                      phx-target={"##{@id}"}
                    >✕</button>
                  </div>
                <% end %>
                <button
                  type="button"
                  class="btn btn-xs btn-outline"
                  phx-click="sq_add_row"
                  phx-value-index={idx}
                  phx-target={"##{@id}"}
                >+ Add row</button>
              </div>

              <form phx-change="sq_toggle_randomize_rows" phx-target={"##{@id}"}>
                <input type="hidden" name="index" value={to_string(idx)} />
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    name="randomize_rows"
                    class="checkbox checkbox-xs"
                    checked={q["randomize_rows"]}
                  />
                  <span class="label-text text-xs">Randomize row order</span>
                </label>
              </form>

              <div class="form-control">
                <label class="label py-0"><span class="label-text text-xs">Cell type</span></label>
                <form phx-change="sq_update_field" phx-target={"##{@id}"}>
                  <input type="hidden" name="index" value={to_string(idx)} />
                  <input type="hidden" name="field" value="cellType" />
                  <select name="value" class="select select-bordered select-xs w-full">
                    <option value="checkbox" selected={Map.get(q, "cellType", "checkbox") == "checkbox"}>Checkbox</option>
                    <option value="radiogroup" selected={Map.get(q, "cellType", "checkbox") == "radiogroup"}>Radio button</option>
                    <option value="text" selected={Map.get(q, "cellType", "checkbox") == "text"}>Free text</option>
                    <option value="number" selected={Map.get(q, "cellType", "checkbox") == "number"}>Number</option>
                  </select>
                </form>
              </div>

              <%= if Map.get(q, "cellType") == "number" do %>
                <div class="flex gap-2">
                  <div class="form-control flex-1">
                    <label class="label py-0"><span class="label-text text-xs">Min</span></label>
                    <form phx-change="sq_update_field" phx-target={"##{@id}"}>
                      <input type="hidden" name="index" value={to_string(idx)} />
                      <input type="hidden" name="field" value="minValue" />
                      <input type="number" name="value" class="input input-bordered input-xs w-full" value={q["minValue"] || ""} />
                    </form>
                  </div>
                  <div class="form-control flex-1">
                    <label class="label py-0"><span class="label-text text-xs">Max</span></label>
                    <form phx-change="sq_update_field" phx-target={"##{@id}"}>
                      <input type="hidden" name="index" value={to_string(idx)} />
                      <input type="hidden" name="field" value="maxValue" />
                      <input type="number" name="value" class="input input-bordered input-xs w-full" value={q["maxValue"] || ""} />
                    </form>
                  </div>
                </div>
              <% end %>

              <%= if q["type"] == "matrix_multiselect" do %>
                <div class="space-y-1">
                  <label class="label py-0"><span class="label-text text-xs">Columns</span></label>
                  <%= for {col, c_idx} <- Enum.with_index(q["columns"] || []) do %>
                    <div class="flex gap-1 items-center">
                      <input
                        type="text"
                        class="input input-bordered input-xs flex-1"
                        value={col}
                        phx-blur="sq_update_column"
                        phx-value-q={idx}
                        phx-value-c={c_idx}
                        phx-target={"##{@id}"}
                      />
                      <button
                        type="button"
                        class="btn btn-xs btn-ghost text-error"
                        phx-click="sq_remove_column"
                        phx-value-q={idx}
                        phx-value-c={c_idx}
                        phx-target={"##{@id}"}
                      >✕</button>
                    </div>
                  <% end %>
                  <button
                    type="button"
                    class="btn btn-xs btn-outline"
                    phx-click="sq_add_column"
                    phx-value-index={idx}
                    phx-target={"##{@id}"}
                  >+ Add column</button>
                </div>
              <% end %>

              <%= if q["type"] == "dynamic_matrix" do %>
                <% dyn_tag_meta = Enum.find(@data_tags, fn dt -> dt["tag"] == q["dyn_source_tag"] end) %>
                <% dyn_matrix_qs = if dyn_tag_meta, do: Enum.filter(dyn_tag_meta["questions"] || [], fn qq -> qq["type"] == "matrix" end), else: [] %>
                <div class="space-y-2 border-l-2 border-info pl-3 pt-1">
                  <p class="text-xs opacity-60">Columns are populated at runtime from a previous survey's matrix response. The first column of the source survey is used as the primary filter; up to 4 dynamic columns are selected across the scale and shuffled.</p>
                  <div class="form-control">
                    <label class="label py-0"><span class="label-text text-xs">Source data tag</span></label>
                    <form phx-change="sq_update_dyn_source_tag" phx-target={"##{@id}"}>
                      <input type="hidden" name="index" value={to_string(idx)} />
                      <select name="value" class="select select-bordered select-xs w-full font-mono">
                        <option value="">tag…</option>
                        <%= for dt <- @data_tags do %>
                          <option value={dt["tag"]} selected={q["dyn_source_tag"] == dt["tag"]}>{dt["tag"]}</option>
                        <% end %>
                      </select>
                    </form>
                  </div>
                  <div class="form-control">
                    <label class="label py-0"><span class="label-text text-xs">Source question</span></label>
                    <form phx-change="sq_update_dyn_source_question" phx-target={"##{@id}"}>
                      <input type="hidden" name="index" value={to_string(idx)} />
                      <select name="value" class="select select-bordered select-xs w-full font-mono">
                        <option value="">question…</option>
                        <%= for qq <- dyn_matrix_qs do %>
                          <option value={qq["name"]} selected={q["dyn_source_question"] == qq["name"]}>{qq["name"]}</option>
                        <% end %>
                      </select>
                    </form>
                  </div>
                  <div class="space-y-1">
                    <label class="label py-0"><span class="label-text text-xs">Fixed columns (always shown)</span></label>
                    <%= for {col, c_idx} <- Enum.with_index(q["static_columns"] || []) do %>
                      <div class="flex gap-1 items-center">
                        <input
                          type="text"
                          class="input input-bordered input-xs flex-1"
                          value={col}
                          phx-blur="sq_update_static_column"
                          phx-value-q={idx}
                          phx-value-c={c_idx}
                          phx-target={"##{@id}"}
                        />
                        <button
                          type="button"
                          class="btn btn-xs btn-ghost text-error"
                          phx-click="sq_remove_static_column"
                          phx-value-q={idx}
                          phx-value-c={c_idx}
                          phx-target={"##{@id}"}
                        >✕</button>
                      </div>
                    <% end %>
                    <button
                      type="button"
                      class="btn btn-xs btn-outline"
                      phx-click="sq_add_static_column"
                      phx-value-index={idx}
                      phx-target={"##{@id}"}
                    >+ Add fixed column</button>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>

      <button
        type="button"
        class="btn btn-sm btn-outline w-full"
        phx-click="sq_add_question"
        phx-target={"##{@id}"}
      >
        + Add question
      </button>

      <div class="form-control">
        <label class="label py-0"><span class="label-text text-xs">Complete button text</span></label>
        <input
          type="text"
          class="input input-bordered input-xs"
          placeholder="Next"
          value={@complete_text}
          phx-blur="sq_set_complete_text"
          phx-target={"##{@id}"}
        />
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".SurveyHtml">
        import { Editor } from "@tiptap/core"
        import StarterKit from "@tiptap/starter-kit"
        import Link from "@tiptap/extension-link"
        import Image from "@tiptap/extension-image"

        export default {
          mounted() {
            const index = this.el.dataset.index
            const field = this.el.dataset.field || "html"
            const componentId = this.el.dataset.componentId
            const initialValue = this.el.dataset.value || ""

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
                this.pushEventTo("#" + componentId, "sq_update_field", { index: index, field: field, value: editor.getHTML() })
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
      <script :type={Phoenix.LiveView.ColocatedHook} name=".SurveyRowText">
        import { Editor } from "@tiptap/core"
        import Document from "@tiptap/extension-document"
        import Paragraph from "@tiptap/extension-paragraph"
        import Text from "@tiptap/extension-text"
        import Bold from "@tiptap/extension-bold"
        import Italic from "@tiptap/extension-italic"
        import Underline from "@tiptap/extension-underline"

        export default {
          mounted() {
            const q = this.el.dataset.q
            const r = this.el.dataset.r
            const componentId = this.el.dataset.componentId
            const initialValue = this.el.dataset.value || ""

            this.toolbar = document.createElement("div")
            this.toolbar.className = "absolute bottom-full left-0 mb-1 flex gap-0.5 bg-base-200 border border-base-300 rounded shadow p-0.5 z-20"
            this.toolbar.style.display = "none"
            this.el.appendChild(this.toolbar)

            const editorEl = document.createElement("div")
            this.el.appendChild(editorEl)

            const toolbarDefs = [
              { label: "B", title: "Bold",      style: "font-bold",  cmd: () => this.editor.chain().focus().toggleBold().run(),      active: () => this.editor.isActive("bold") },
              { label: "I", title: "Italic",    style: "italic",     cmd: () => this.editor.chain().focus().toggleItalic().run(),    active: () => this.editor.isActive("italic") },
              { label: "U", title: "Underline", style: "underline",  cmd: () => this.editor.chain().focus().toggleUnderline().run(), active: () => this.editor.isActive("underline") },
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
              extensions: [Document, Paragraph, Text, Bold, Italic, Underline],
              content: initialValue,
              editorProps: { attributes: { class: "input input-bordered input-xs w-full outline-none cursor-text" } },
              onUpdate: ({ editor }) => {
                this.pushEventTo("#" + componentId, "sq_update_row", { q: q, r: r, value: editor.getHTML() })
              },
              onTransaction: () => {
                const btns = this.toolbar.querySelectorAll("button")
                toolbarDefs.forEach(({ active }, i) => {
                  btns[i]?.classList.toggle("btn-active", active())
                })
              },
            })

            this.editor.on("focus", () => {
              clearTimeout(this._blurTimer)
              this.toolbar.style.display = "flex"
            })
            this.editor.on("blur", () => {
              this._blurTimer = setTimeout(() => { this.toolbar.style.display = "none" }, 150)
            })
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
    </div>
    """
  end

  defp new_row, do: %{"text" => "", "reversed" => false}

  defp parse_numeric(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, ""} -> n
      _ ->
        case Float.parse(v) do
          {f, ""} -> f
          _ -> nil
        end
    end
  end
  defp parse_numeric(v) when is_number(v), do: v
  defp parse_numeric(_), do: nil

  defp maybe_put_numeric(map, _key, nil), do: map
  defp maybe_put_numeric(map, key, val), do: Map.put(map, key, val)

  defp normalize_row(r) when is_binary(r), do: %{"text" => r, "reversed" => false}
  defp normalize_row(%{"text" => _} = r), do: r
  defp normalize_row(_), do: new_row()

  defp rows_to_surveyjs(rows) do
    Enum.map(rows, fn row ->
      r = normalize_row(row)
      plain = Regex.replace(~r/<[^>]+>/, r["text"], "")
      %{"value" => plain, "text" => r["text"], "reversed" => r["reversed"] || false}
    end)
  end

  defp notify_parent(socket) do
    json = to_survey_json(socket.assigns.questions, socket.assigns.complete_text)
    send(self(), {:survey_builder_update, json})
  end

  # ── Serialize to Survey.js JSON ─────────────────────────────────────────────

  defp to_survey_json([], _complete_text), do: %{}

  defp to_survey_json(questions, complete_text) do
    %{
      "elements" => Enum.map(questions, &question_to_element/1),
      "completeText" => if(complete_text && complete_text != "", do: complete_text, else: "Next"),
      "widthMode" => "responsive"
    }
  end

  defp question_to_element(%{"type" => "html"} = q) do
    %{"type" => "html", "name" => q["name"], "html" => q["html"] || ""}
  end

  defp question_to_element(%{"type" => "dynamic_matrix"} = q) do
    cell_type = q["cellType"] || "checkbox"
    base = %{
      "name" => q["name"],
      "title" => q["title"],
      "isRequired" => q["isRequired"] || false,
      "eachRowRequired" => q["isRequired"] || false,
      "rows" => rows_to_surveyjs(q["rows"] || []),
      "columns" => [],
      "cellType" => cell_type,
      "rowsOrder" => if(q["randomize_rows"], do: "random", else: "initial"),
      "dyn_source_tag" => q["dyn_source_tag"] || "",
      "dyn_source_question" => q["dyn_source_question"] || "",
      "dyn_source_columns" => q["dyn_source_columns"] || [],
      "static_columns" => q["static_columns"] || []
    }
    case cell_type do
      "checkbox" -> Map.merge(base, %{"type" => "matrix", "multiSelect" => true})
      "text"     -> Map.put(base, "type", "matrixdropdown")
      "number"   ->
        min = parse_numeric(q["minValue"])
        max = parse_numeric(q["maxValue"])
        base
        |> Map.put("type", "matrixdropdown")
        |> Map.delete("cellType")
        |> maybe_put_numeric("min", min)
        |> maybe_put_numeric("max", max)
        |> Map.put("cellType", "text")
        |> Map.put("inputType", "number")
      _ -> Map.merge(base, %{"type" => "matrix", "multiSelect" => false})
    end
  end

  defp question_to_element(%{"type" => "matrix_multiselect"} = q) do
    cell_type = q["cellType"] || "checkbox"
    base = %{
      "name" => q["name"],
      "title" => q["title"],
      "isRequired" => q["isRequired"] || false,
      "eachRowRequired" => q["isRequired"] || false,
      "rows" => rows_to_surveyjs(q["rows"] || []),
      "cellType" => cell_type,
      "rowsOrder" => if(q["randomize_rows"], do: "random", else: "initial")
    }
    case cell_type do
      "checkbox" ->
        Map.merge(base, %{"type" => "matrix", "multiSelect" => true, "columns" => q["columns"] || []})
      "text" ->
        cols = Enum.map(q["columns"] || [], fn c -> %{"name" => c, "title" => c} end)
        Map.merge(base, %{"type" => "matrixdropdown", "columns" => cols})
      "number" ->
        min = parse_numeric(q["minValue"])
        max = parse_numeric(q["maxValue"])
        cols = Enum.map(q["columns"] || [], fn c -> %{"name" => c, "title" => c} end)
        base
        |> Map.put("type", "matrixdropdown")
        |> Map.delete("cellType")
        |> Map.put("cellType", "text")
        |> Map.put("inputType", "number")
        |> maybe_put_numeric("min", min)
        |> maybe_put_numeric("max", max)
        |> Map.put("columns", cols)
      _ ->
        Map.merge(base, %{"type" => "matrix", "multiSelect" => false, "columns" => q["columns"] || []})
    end
  end

  defp question_to_element(q) do
    %{
      "type" => survey_js_type(q["type"]),
      "name" => q["name"],
      "title" => q["title"],
      "isRequired" => q["isRequired"] || false
    }
    |> maybe_put_input_type(q)
    |> maybe_put_choices(q)
    |> maybe_put_validators(q)
    |> maybe_put_word_limits(q)
  end

  # Survey.js uses type "text" with inputType "number" for numeric inputs
  defp survey_js_type("number"), do: "text"
  defp survey_js_type(t), do: t

  defp maybe_put_input_type(el, %{"type" => "number"}), do: Map.put(el, "inputType", "number")
  defp maybe_put_input_type(el, %{"type" => "text", "inputType" => "email"}), do: Map.put(el, "inputType", "email")
  defp maybe_put_input_type(el, %{"type" => "text", "inputType" => "phone"}), do: Map.put(el, "inputType", "tel")
  defp maybe_put_input_type(el, _), do: el

  defp maybe_put_choices(el, %{"type" => t, "choices" => [_ | _] = choices})
       when t in @choice_types,
       do: Map.put(el, "choices", choices)

  defp maybe_put_choices(el, _), do: el

  defp maybe_put_validators(el, %{"type" => "number"} = q) do
    min = parse_number(q["minValue"])
    max = parse_number(q["maxValue"])

    if min || max do
      validator =
        %{"type" => "numeric"}
        |> then(&if(min, do: Map.put(&1, "minValue", min), else: &1))
        |> then(&if(max, do: Map.put(&1, "maxValue", max), else: &1))

      Map.put(el, "validators", [validator])
    else
      el
    end
  end

  defp maybe_put_validators(el, %{"type" => "text"} = q) do
    case q["inputType"] do
      "email" ->
        Map.put(el, "validators", [%{"type" => "email"}])
      "phone" ->
        Map.put(el, "validators", [%{
          "type" => "regex",
          "regex" => "^[+]?[0-9(). -]{7,20}$",
          "text" => "Please enter a valid phone number"
        }])
      _ -> el
    end
  end

  defp maybe_put_validators(el, _), do: el

  defp maybe_put_word_limits(el, %{"type" => "text"} = q) do
    case q["inputType"] || "free" do
      "free" ->
        min = parse_numeric(q["minWords"])
        max = parse_numeric(q["maxWords"])
        el
        |> then(&if(min && min > 0, do: Map.put(&1, "minWords", trunc(min)), else: &1))
        |> then(&if(max && max > 0, do: Map.put(&1, "maxWords", trunc(max)), else: &1))
      _ ->
        el
    end
  end

  defp maybe_put_word_limits(el, _), do: el

  defp parse_number(v) when v in [nil, ""], do: nil
  defp parse_number(v) when is_number(v), do: v

  defp parse_number(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, ""} -> n
      _ ->
        case Float.parse(v) do
          {f, ""} -> f
          _ -> nil
        end
    end
  end

  # ── Deserialize from stored Survey.js JSON ───────────────────────────────────

  defp parse_survey_json(v) when v in [nil, %{}],
    do: %{questions: [], complete_text: "Next"}

  defp parse_survey_json(%{"elements" => els} = json) when is_list(els) do
    %{
      questions: Enum.with_index(els, fn el, i -> element_to_question(el, i) end),
      complete_text: json["completeText"] || "Next"
    }
  end

  defp parse_survey_json(_), do: %{questions: [], complete_text: "Next"}

  defp element_to_question(%{"type" => "html"} = el, i) do
    %{
      "type" => "html",
      "name" => el["name"] || "content#{i + 1}",
      "html" => el["html"] || "",
      "title" => "",
      "isRequired" => false,
      "choices" => [],
      "minValue" => "",
      "maxValue" => ""
    }
  end

  defp element_to_question(%{"type" => "matrix", "dyn_source_tag" => tag} = el, i)
       when is_binary(tag) and tag != "" do
    rows =
      (el["rows"] || [])
      |> Enum.map(fn
        r when is_binary(r) -> %{"text" => r, "reversed" => false}
        %{"text" => t, "reversed" => rev} -> %{"text" => t, "reversed" => rev || false}
        %{"text" => t} -> %{"text" => t, "reversed" => false}
        _ -> new_row()
      end)

    %{
      "type" => "dynamic_matrix",
      "name" => el["name"] || "question#{i + 1}",
      "title" => el["title"] || "",
      "html" => "",
      "isRequired" => el["isRequired"] || false,
      "choices" => [],
      "minValue" => "",
      "maxValue" => "",
      "rows" => rows,
      "columns" => [],
      "cellType" => el["cellType"] || "checkbox",
      "dyn_source_tag" => tag,
      "dyn_source_question" => el["dyn_source_question"] || "",
      "dyn_source_columns" => el["dyn_source_columns"] || [],
      "static_columns" => el["static_columns"] || [],
      "randomize_rows" => el["rowsOrder"] == "random"
    }
  end

  defp element_to_question(%{"type" => "matrix"} = el, i) do
    rows =
      (el["rows"] || [])
      |> Enum.map(fn
        r when is_binary(r) -> %{"text" => r, "reversed" => false}
        %{"text" => t, "reversed" => rev} -> %{"text" => t, "reversed" => rev || false}
        %{"text" => t} -> %{"text" => t, "reversed" => false}
        _ -> new_row()
      end)

    %{
      "type" => "matrix_multiselect",
      "name" => el["name"] || "question#{i + 1}",
      "title" => el["title"] || "",
      "html" => "",
      "isRequired" => el["isRequired"] || false,
      "choices" => [],
      "minValue" => "",
      "maxValue" => "",
      "rows" => rows,
      "columns" => el["columns"] || [],
      "cellType" => el["cellType"] || "checkbox",
      "randomize_rows" => el["rowsOrder"] == "random"
    }
  end

  defp element_to_question(%{"type" => "matrixdropdown", "dyn_source_tag" => tag} = el, i)
       when is_binary(tag) and tag != "" do
    rows =
      (el["rows"] || [])
      |> Enum.map(fn
        r when is_binary(r) -> %{"text" => r, "reversed" => false}
        %{"text" => t, "reversed" => rev} -> %{"text" => t, "reversed" => rev || false}
        %{"text" => t} -> %{"text" => t, "reversed" => false}
        _ -> new_row()
      end)

    cell_type = if el["inputType"] == "number", do: "number", else: el["cellType"] || "text"

    %{
      "type" => "dynamic_matrix",
      "name" => el["name"] || "question#{i + 1}",
      "title" => el["title"] || "",
      "html" => "",
      "isRequired" => el["isRequired"] || false,
      "choices" => [],
      "minValue" => to_string(el["min"] || ""),
      "maxValue" => to_string(el["max"] || ""),
      "rows" => rows,
      "columns" => [],
      "cellType" => cell_type,
      "dyn_source_tag" => tag,
      "dyn_source_question" => el["dyn_source_question"] || "",
      "dyn_source_columns" => el["dyn_source_columns"] || [],
      "static_columns" => el["static_columns"] || [],
      "randomize_rows" => el["rowsOrder"] == "random"
    }
  end

  defp element_to_question(%{"type" => "matrixdropdown"} = el, i) do
    rows =
      (el["rows"] || [])
      |> Enum.map(fn
        r when is_binary(r) -> %{"text" => r, "reversed" => false}
        %{"text" => t, "reversed" => rev} -> %{"text" => t, "reversed" => rev || false}
        %{"text" => t} -> %{"text" => t, "reversed" => false}
        _ -> new_row()
      end)

    columns =
      Enum.map(el["columns"] || [], fn
        col when is_binary(col) -> col
        %{"name" => name} -> name
        _ -> ""
      end)

    cell_type = if el["inputType"] == "number", do: "number", else: el["cellType"] || "text"

    %{
      "type" => "matrix_multiselect",
      "name" => el["name"] || "question#{i + 1}",
      "title" => el["title"] || "",
      "html" => "",
      "isRequired" => el["isRequired"] || false,
      "choices" => [],
      "minValue" => to_string(el["min"] || ""),
      "maxValue" => to_string(el["max"] || ""),
      "rows" => rows,
      "columns" => columns,
      "cellType" => cell_type,
      "randomize_rows" => el["rowsOrder"] == "random"
    }
  end

  defp element_to_question(el, i) do
    {type, input_type} =
      case {el["type"], el["inputType"]} do
        {"text", "number"} -> {"number", "free"}
        {"text", "email"}  -> {"text", "email"}
        {"text", "tel"}    -> {"text", "phone"}
        {t, _}             -> {t || "text", "free"}
      end

    {min_v, max_v} = extract_numeric_validator(el)

    %{
      "type" => type,
      "name" => el["name"] || "question#{i + 1}",
      "title" => el["title"] || "",
      "html" => "",
      "isRequired" => el["isRequired"] || false,
      "choices" => normalize_choices(el["choices"]),
      "minValue" => to_string(min_v || ""),
      "maxValue" => to_string(max_v || ""),
      "inputType" => input_type,
      "minWords" => to_string(el["minWords"] || ""),
      "maxWords" => to_string(el["maxWords"] || "")
    }
  end

  defp normalize_choices(nil), do: []

  defp normalize_choices(choices) do
    Enum.map(choices, fn
      c when is_binary(c) -> c
      %{"value" => v} -> to_string(v)
      %{"text" => t} -> to_string(t)
      _ -> ""
    end)
  end

  defp extract_numeric_validator(%{"validators" => [%{"type" => "numeric"} = v | _]}),
    do: {v["minValue"], v["maxValue"]}

  defp extract_numeric_validator(_), do: {nil, nil}
end
