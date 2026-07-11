defmodule SochoWeb.StudyLive.SurveyBuilderComponent do
  use SochoWeb, :live_component

  @question_types [
    {"text", "Short text"},
    {"number", "Number"},
    {"comment", "Long text"},
    {"radiogroup", "Single choice"},
    {"checkbox", "Multiple choice"},
    {"dropdown", "Dropdown"},
    {"rating", "Rating scale"},
    {"boolean", "Yes / No"}
  ]

  @choice_types ["radiogroup", "checkbox", "dropdown"]

  @impl true
  def update(%{value: value, field_name: field_name} = assigns, socket) do
    socket =
      if Map.has_key?(socket.assigns, :questions) do
        assign(socket, id: assigns.id, field_name: field_name)
      else
        assign(socket,
          id: assigns.id,
          field_name: field_name,
          questions: parse_survey_json(value),
          question_types: @question_types,
          choice_types: @choice_types
        )
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
      "isRequired" => false,
      "choices" => [],
      "minValue" => "",
      "maxValue" => ""
    }

    socket = update(socket, :questions, fn qs -> qs ++ [new_q] end)
    {:noreply, socket}
  end

  def handle_event("sq_remove_question", %{"index" => idx}, socket) do
    idx = String.to_integer(idx)
    socket = update(socket, :questions, fn qs -> List.delete_at(qs, idx) end)
    {:noreply, socket}
  end

  def handle_event("sq_set_type", %{"index" => idx, "type" => type_val}, socket) do
    idx = String.to_integer(idx)
    socket = update(socket, :questions, fn qs -> List.update_at(qs, idx, fn q -> Map.put(q, "type", type_val) end) end)
    {:noreply, socket}
  end

  def handle_event("sq_update_field", %{"index" => idx, "field" => field, "value" => val}, socket) do
    idx = String.to_integer(idx)
    socket = update(socket, :questions, fn qs -> List.update_at(qs, idx, fn q -> Map.put(q, field, val) end) end)
    {:noreply, socket}
  end

  def handle_event("sq_toggle_required", %{"index" => idx}, socket) do
    idx = String.to_integer(idx)

    socket =
      update(socket, :questions, fn qs ->
        List.update_at(qs, idx, fn q -> Map.update(q, "isRequired", true, fn v -> !v end) end)
      end)

    {:noreply, socket}
  end

  def handle_event("sq_add_choice", %{"index" => idx}, socket) do
    idx = String.to_integer(idx)

    socket =
      update(socket, :questions, fn qs ->
        List.update_at(qs, idx, fn q -> Map.update(q, "choices", [""], fn cs -> cs ++ [""] end) end)
      end)

    {:noreply, socket}
  end

  def handle_event("sq_remove_choice", %{"q" => q_i, "c" => c_i}, socket) do
    q_i = String.to_integer(q_i)
    c_i = String.to_integer(c_i)

    socket =
      update(socket, :questions, fn qs ->
        List.update_at(qs, q_i, fn q -> Map.update(q, "choices", [], fn cs -> List.delete_at(cs, c_i) end) end)
      end)

    {:noreply, socket}
  end

  def handle_event("sq_update_choice", %{"q" => q_i, "c" => c_i, "value" => val}, socket) do
    q_i = String.to_integer(q_i)
    c_i = String.to_integer(c_i)

    socket =
      update(socket, :questions, fn qs ->
        List.update_at(qs, q_i, fn q -> Map.update(q, "choices", [], fn cs -> List.replace_at(cs, c_i, val) end) end)
      end)

    {:noreply, socket}
  end

  # ── Render ──────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :encoded, Jason.encode!(to_survey_json(assigns.questions)))

    ~H"""
    <div id={@id} class="space-y-3">
      <%!-- Hidden input carries the serialized survey_json into the parent form submit --%>
      <input type="hidden" name={@field_name} value={@encoded} />

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

          <div class="form-control">
            <label class="label py-0"><span class="label-text text-xs">Question text</span></label>
            <input
              type="text"
              class="input input-bordered input-xs"
              placeholder="Enter question..."
              value={q["title"]}
              phx-blur="sq_update_field"
              phx-value-index={idx}
              phx-value-field="title"
              phx-target={"##{@id}"}
            />
          </div>

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

          <div class="flex items-center gap-2">
            <input
              type="checkbox"
              class="checkbox checkbox-xs"
              checked={q["isRequired"]}
              phx-click="sq_toggle_required"
              phx-value-index={idx}
              phx-target={"##{@id}"}
            />
            <span class="text-xs">Required</span>
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
        </div>
      <% end %>

      <button
        type="button"
        class="btn btn-sm btn-outline w-full"
        phx-click="sq_add_question"
        phx-target={@myself}
      >
        + Add question
      </button>
    </div>
    """
  end

  # ── Serialize to Survey.js JSON ─────────────────────────────────────────────

  defp to_survey_json([]), do: %{}

  defp to_survey_json(questions) do
    %{"elements" => Enum.map(questions, &question_to_element/1)}
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
  end

  # Survey.js uses type "text" with inputType "number" for numeric inputs
  defp survey_js_type("number"), do: "text"
  defp survey_js_type(t), do: t

  defp maybe_put_input_type(el, %{"type" => "number"}), do: Map.put(el, "inputType", "number")
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

  defp maybe_put_validators(el, _), do: el

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

  defp parse_survey_json(v) when v in [nil, %{}], do: []

  defp parse_survey_json(%{"elements" => els}) when is_list(els) do
    Enum.with_index(els, fn el, i -> element_to_question(el, i) end)
  end

  defp parse_survey_json(_), do: []

  defp element_to_question(el, i) do
    type =
      if el["type"] == "text" and el["inputType"] == "number",
        do: "number",
        else: el["type"] || "text"

    {min_v, max_v} = extract_numeric_validator(el)

    %{
      "type" => type,
      "name" => el["name"] || "question#{i + 1}",
      "title" => el["title"] || "",
      "isRequired" => el["isRequired"] || false,
      "choices" => normalize_choices(el["choices"]),
      "minValue" => to_string(min_v || ""),
      "maxValue" => to_string(max_v || "")
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
