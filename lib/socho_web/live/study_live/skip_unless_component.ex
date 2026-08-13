defmodule SochoWeb.StudyLive.SkipUnlessComponent do
  use SochoWeb, :live_component

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  # ── Events ─────────────────────────────────────────────────────────────────

  def handle_event("skip_add_condition", _params, socket) do
    skip = socket.assigns.skip_unless || %{"mode" => "gui", "join" => "AND", "conditions" => []}
    new_cond = %{"tag" => "", "field" => "response", "question" => "", "op" => "eq", "value" => "", "negate" => false}
    updated = Map.update(skip, "conditions", [new_cond], &(&1 ++ [new_cond]))
    notify_parent(updated)
    {:noreply, socket}
  end

  def handle_event("skip_remove_condition", %{"index" => idx_str}, socket) do
    skip = socket.assigns.skip_unless || %{"mode" => "gui", "join" => "AND", "conditions" => []}
    updated_conds = (skip["conditions"] || []) |> List.delete_at(String.to_integer(idx_str))
    updated = if updated_conds == [], do: nil, else: Map.put(skip, "conditions", updated_conds)
    notify_parent(updated)
    {:noreply, socket}
  end

  def handle_event("skip_update_condition", %{"skip_cond" => conds_map}, socket) do
    skip = socket.assigns.skip_unless || %{"mode" => "gui", "join" => "AND", "conditions" => []}
    existing_conds = skip["conditions"] || []

    updated_conditions =
      existing_conds
      |> Enum.with_index()
      |> Enum.map(fn {existing, idx} ->
        case Map.get(conds_map, to_string(idx)) do
          nil ->
            existing

          form_vals ->
            merged = Map.merge(existing, form_vals)
            if Map.has_key?(form_vals, "tag") && form_vals["tag"] != existing["tag"],
              do: Map.put(merged, "question", ""),
              else: merged
        end
      end)

    updated = Map.put(skip, "conditions", updated_conditions)
    notify_parent(updated)
    {:noreply, socket}
  end

  def handle_event("skip_toggle_negate", %{"index" => idx_str}, socket) do
    skip = socket.assigns.skip_unless || %{"mode" => "gui", "join" => "AND", "conditions" => []}
    idx = String.to_integer(idx_str)
    conditions = skip["conditions"] || []
    existing = Enum.at(conditions, idx, %{})
    updated_cond = Map.put(existing, "negate", !existing["negate"])
    updated = Map.put(skip, "conditions", List.replace_at(conditions, idx, updated_cond))
    notify_parent(updated)
    {:noreply, socket}
  end

  def handle_event("skip_toggle_join", _params, socket) do
    skip = socket.assigns.skip_unless || %{"mode" => "gui", "join" => "AND", "conditions" => []}
    new_join = if skip["join"] == "OR", do: "AND", else: "OR"
    notify_parent(Map.put(skip, "join", new_join))
    {:noreply, socket}
  end

  def handle_event("skip_toggle_mode", _params, socket) do
    skip = socket.assigns.skip_unless || %{"mode" => "gui", "join" => "AND", "conditions" => []}
    new_mode = if skip["mode"] == "raw", do: "gui", else: "raw"
    notify_parent(Map.put(skip, "mode", new_mode))
    {:noreply, socket}
  end

  # ── Render ──────────────────────────────────────────────────────────────────

  def render(assigns) do
    skip = assigns.skip_unless
    assigns =
      assign(assigns,
        skip: skip,
        mode: (skip || %{})["mode"],
        conditions: (skip || %{})["conditions"] || [],
        join: (skip || %{})["join"] || "AND"
      )

    ~H"""
    <div class="form-control gap-2">
      <div class="flex items-center justify-between">
        <p class="text-sm font-medium leading-tight">Skip unless…</p>
        <button
          type="button"
          class="btn btn-xs btn-ghost opacity-50"
          phx-click="skip_toggle_mode"
          phx-target={@myself}
          title={if @mode == "raw", do: "Switch to visual builder", else: "Switch to raw JS"}
        >
          <%= if @mode == "raw", do: "↩ visual", else: "⌨ raw JS" %>
        </button>
      </div>

      <%= if @mode == "raw" do %>
        <textarea
          class="textarea textarea-bordered text-xs font-mono leading-snug w-full"
          name="config[conditional_function]"
          rows="4"
          placeholder={"// Return true to run this block, false to skip it\nconst d = jsPsych.data.get().last(1).values()[0];\nreturn d.response === \"yes\";"}
          phx-debounce="300"
        >{@conditional_function}</textarea>
        <p class="text-xs opacity-50 leading-snug">
          JS function body. Return <code class="font-mono">true</code> to run this block, <code class="font-mono">false</code> to skip it.
        </p>
      <% else %>
        <%!-- Condition rows --%>
        <%= for {cond, i} <- Enum.with_index(@conditions) do %>
          <% field = cond["field"] || "response" %>
          <% op = cond["op"] || "eq" %>
          <% tag_meta = Enum.find(@data_tags, fn dt -> dt["tag"] == cond["tag"] end) %>
          <% is_survey_tag = tag_meta && tag_meta["plugin"] == "survey" %>
          <% survey_questions = if is_survey_tag, do: tag_meta["questions"] || [], else: [] %>
          <% selected_question = Enum.find(survey_questions, fn q -> q["name"] == cond["question"] end) %>
          <% question_choices = if selected_question, do: selected_question["choices"] || [], else: [] %>
          <% is_numeric_question = selected_question != nil && (selected_question["inputType"] == "number" || selected_question["type"] == "rating") %>
          <div class="flex flex-wrap items-center gap-1">
            <label class="flex items-center gap-1 cursor-pointer shrink-0" title="NOT">
              <input
                type="checkbox"
                class="checkbox checkbox-xs"
                checked={cond["negate"] == true}
                phx-click="skip_toggle_negate"
                phx-target={@myself}
                phx-value-index={i}
              />
              <span class="text-xs opacity-40">!</span>
            </label>
            <select
              class="select select-xs select-bordered w-auto shrink-0"
              phx-change="skip_update_condition"
              phx-target={@myself}
              name={"skip_cond[#{i}][tag]"}
            >
              <option value="" disabled={cond["tag"] != ""}>tag…</option>
              <%= for dt <- @data_tags do %>
                <option value={dt["tag"]} selected={cond["tag"] == dt["tag"]}>{dt["tag"]}</option>
              <% end %>
              <%= if cond["tag"] != "" && !Enum.any?(@data_tags, fn dt -> dt["tag"] == cond["tag"] end) do %>
                <option value={cond["tag"]} selected>{cond["tag"]}</option>
              <% end %>
            </select>
            <select
              class="select select-xs select-bordered w-auto shrink-0"
              phx-change="skip_update_condition"
              phx-target={@myself}
              name={"skip_cond[#{i}][field]"}
            >
              <option value="response" selected={field == "response"}>response</option>
              <option value="correct" selected={field == "correct"}>correct</option>
              <option value="rt" selected={field == "rt"}>rt</option>
            </select>
            <%!-- Question picker — only for survey tags + response field --%>
            <%= if is_survey_tag && field == "response" && survey_questions != [] do %>
              <select
                class="select select-xs select-bordered w-auto shrink-0"
                phx-change="skip_update_condition"
                phx-target={@myself}
                name={"skip_cond[#{i}][question]"}
              >
                <option value="" disabled={cond["question"] != ""}>question…</option>
                <%= for q <- survey_questions do %>
                  <option value={q["name"]} selected={cond["question"] == q["name"]}>
                    {q["name"]}
                  </option>
                <% end %>
              </select>
            <% end %>
            <select
              class="select select-xs select-bordered w-auto shrink-0"
              phx-change="skip_update_condition"
              phx-target={@myself}
              name={"skip_cond[#{i}][op]"}
            >
              <%= if field == "correct" do %>
                <option value="is_true" selected={op == "is_true"}>true</option>
                <option value="is_false" selected={op == "is_false"}>false</option>
              <% else %>
                <option value="eq" selected={op == "eq"}>=</option>
                <option value="neq" selected={op == "neq"}>≠</option>
                <%= if field == "response" && !selected_question do %>
                  <option value="contains" selected={op == "contains"}>has</option>
                <% end %>
                <%= if field == "rt" || is_numeric_question do %>
                  <option value="lt" selected={op == "lt"}>&#60;</option>
                  <option value="gt" selected={op == "gt"}>&#62;</option>
                <% end %>
              <% end %>
            </select>
            <%= if op not in ["is_true", "is_false"] do %>
              <%= if question_choices != [] do %>
                <select
                  class="select select-xs select-bordered w-auto shrink-0"
                  phx-change="skip_update_condition"
                  phx-target={@myself}
                  name={"skip_cond[#{i}][value]"}
                >
                  <option value="" disabled={cond["value"] != ""}>value…</option>
                  <%= for choice <- question_choices do %>
                    <option value={choice} selected={cond["value"] == choice}>{choice}</option>
                  <% end %>
                </select>
              <% else %>
                <input
                  type="text"
                  class="input input-xs input-bordered w-20 shrink-0"
                  value={cond["value"] || ""}
                  placeholder="val"
                  phx-change="skip_update_condition"
                  phx-target={@myself}
                  phx-debounce="300"
                  name={"skip_cond[#{i}][value]"}
                />
              <% end %>
            <% end %>
            <button
              type="button"
              class="btn btn-xs btn-ghost text-error shrink-0"
              phx-click="skip_remove_condition"
              phx-target={@myself}
              phx-value-index={i}
            >✕</button>
          </div>
          <%!-- Join badge between conditions --%>
          <%= if i < length(@conditions) - 1 do %>
            <div class="flex justify-start">
              <button
                type="button"
                class="badge badge-sm cursor-pointer bg-base-200 border-base-200 hover:bg-base-300 hover:border-base-300 my-1"
                phx-click="skip_toggle_join"
                phx-target={@myself}
                title="Click to toggle AND / OR"
              >{@join}</button>
            </div>
          <% end %>
        <% end %>

        <button
          type="button"
          class="btn btn-xs btn-outline w-full"
          phx-click="skip_add_condition"
          phx-target={@myself}
        >+ Add condition</button>

        <%= if @conditions == [] do %>
          <p class="text-xs opacity-40 text-center">No conditions — block always runs.</p>
        <% end %>
        <%= if @data_tags == [] do %>
          <p class="text-xs opacity-50 leading-snug mt-1">
            Tip: set a <strong>Tag</strong> on any block (in its Identification section) to reference its response here.
          </p>
        <% end %>
      <% end %>
    </div>
    """
  end

  # ── Private ─────────────────────────────────────────────────────────────────

  defp notify_parent(new_skip_unless) do
    send(self(), {:skip_unless_update, new_skip_unless})
  end
end
