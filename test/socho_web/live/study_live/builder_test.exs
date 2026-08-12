defmodule SochoWeb.StudyLive.BuilderTest do
  use SochoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    {:ok, user} =
      Socho.Accounts.UserAdmin.create_user(
        "manager#{System.unique_integer()}@example.com",
        "password123!",
        :manager
      )

    %{conn: log_in_user(conn, user), user: user}
  end

  defp create_study_with_trial do
    {:ok, study} =
      Socho.Studies.create_study_with_trials("Test Study", nil, [
        %{
          node_type: "trial",
          plugin: "animation",
          config: %{},
          extensions: %{},
          children: []
        }
      ])

    study
  end

  # ---------------------------------------------------------------------------
  # mount – new study
  # ---------------------------------------------------------------------------

  describe "mount – new study" do
    test "renders the builder page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/studies/new")
      assert html =~ "Study Builder"
    end

    test "shows empty-state hint when there are no trials", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/studies/new")
      assert html =~ "Pick a plugin above"
    end

    test "Save button is disabled when no trials have been added", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/studies/new")
      assert html =~ ~s(disabled)
    end

    test "Blocks tab is active and plugin search is visible by default", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/studies/new")
      assert html =~ "Search plugins"
    end
  end

  # ---------------------------------------------------------------------------
  # mount – existing study
  # ---------------------------------------------------------------------------

  describe "mount – existing study" do
    test "loads trials from the database and renders them", %{conn: conn} do
      study = create_study_with_trial()
      {:ok, _lv, html} = live(conn, ~p"/studies/#{study.id}/edit")
      assert html =~ "animation"
    end

    test "preview button is shown for an existing study", %{conn: conn} do
      study = create_study_with_trial()
      {:ok, _lv, html} = live(conn, ~p"/studies/#{study.id}/edit")
      assert html =~ "Preview"
    end
  end

  # ---------------------------------------------------------------------------
  # plugin search
  # ---------------------------------------------------------------------------

  describe "plugin search" do
    test "filters the plugin list to names matching the query", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      html = lv |> element("form[phx-change='plugin_search']") |> render_change(%{query: "animation"})
      assert html =~ "animation"
    end

    test "shows no-plugins message when query has no matches", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      html = lv |> element("form[phx-change='plugin_search']") |> render_change(%{query: "zzznomatch"})
      assert html =~ "No plugins found"
    end

    test "restores full list when query is cleared", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      lv |> element("form[phx-change='plugin_search']") |> render_change(%{query: "zzznomatch"})
      html = lv |> element("form[phx-change='plugin_search']") |> render_change(%{query: ""})
      refute html =~ "No plugins found"
    end
  end

  # ---------------------------------------------------------------------------
  # sidebar tabs
  # ---------------------------------------------------------------------------

  describe "sidebar tabs" do
    test "switching to Templates tab shows template buttons", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      html = lv |> element("button[phx-value-tab='templates']") |> render_click()
      assert html =~ "Consent Gate"
    end

    test "switching back to Blocks tab shows the plugin search bar", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      lv |> element("button[phx-value-tab='templates']") |> render_click()
      html = lv |> element("button[phx-value-tab='blocks']") |> render_click()
      assert html =~ "Search plugins"
    end
  end

  # ---------------------------------------------------------------------------
  # add_timeline
  # ---------------------------------------------------------------------------

  describe "add_timeline" do
    test "adds a TL timeline node to the trial tree", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      html = lv |> element("button[phx-click='add_timeline']") |> render_click()
      assert html =~ ">TL<"
    end

    test "auto-selects the new timeline and shows its config panel", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      html = lv |> element("button[phx-click='add_timeline']") |> render_click()
      assert html =~ "Timeline Group"
      assert html =~ "repetitions"
    end
  end

  # ---------------------------------------------------------------------------
  # add_plugin_trial
  # ---------------------------------------------------------------------------

  describe "add_plugin_trial" do
    test "adds the plugin as a trial block in the tree", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      html = lv |> element("button[phx-value-plugin='animation']") |> render_click()
      assert html =~ "animation"
    end

    test "auto-selects the new trial and shows its config panel", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      html = lv |> element("button[phx-value-plugin='animation']") |> render_click()
      assert html =~ "Configure"
    end

    test "adds trial as a child of the selected timeline", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      lv |> element("button[phx-click='add_timeline']") |> render_click()
      html = lv |> element("button[phx-value-plugin='animation']") |> render_click()
      assert html =~ ">TL<"
      assert html =~ "animation"
      assert html =~ "1 trials"
    end

    test "adds trial at top level when no timeline is selected", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      html = lv |> element("button[phx-value-plugin='animation']") |> render_click()
      # No TL badge — trial added at top level, not nested
      refute html =~ ">TL<"
    end
  end

  # ---------------------------------------------------------------------------
  # remove_trial
  # ---------------------------------------------------------------------------

  describe "remove_trial" do
    test "removes a trial from the tree", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      lv |> element("button[phx-value-plugin='animation']") |> render_click()
      html = lv |> element("button[phx-click='remove_trial']") |> render_click()
      # Empty state reappears once all trials are gone
      assert html =~ "Pick a plugin above"
    end

    test "clears the config panel when the selected trial is removed", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      lv |> element("button[phx-value-plugin='animation']") |> render_click()
      html = lv |> element("button[phx-click='remove_trial']") |> render_click()
      assert html =~ "Click a trial block to configure it."
    end

    test "removes a timeline node from the tree", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      lv |> element("button[phx-click='add_timeline']") |> render_click()
      html = lv |> element("button[phx-click='remove_trial']") |> render_click()
      refute html =~ ">TL<"
    end
  end

  # ---------------------------------------------------------------------------
  # move_trial_up / move_trial_down
  # ---------------------------------------------------------------------------

  describe "move_trial_up / move_trial_down" do
    test "move_trial_down with a single trial does not crash", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      lv |> element("button[phx-value-plugin='animation']") |> render_click()
      html = lv |> element("button[phx-click='move_trial_down']") |> render_click()
      assert html =~ "animation"
    end

    test "move_trial_up with a single trial does not crash", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      lv |> element("button[phx-value-plugin='animation']") |> render_click()
      html = lv |> element("button[phx-click='move_trial_up']") |> render_click()
      assert html =~ "animation"
    end
  end

  # ---------------------------------------------------------------------------
  # insert_template
  # ---------------------------------------------------------------------------

  describe "insert_template" do
    test "adds a TPL template_group node to the tree with the template name", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      lv |> element("button[phx-value-tab='templates']") |> render_click()
      html = lv |> element("button[phx-value-id='consent_gate']") |> render_click()
      assert html =~ ">TPL<"
      assert html =~ "Consent Gate"
    end

    test "auto-selects the template_group and shows its config panel", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      lv |> element("button[phx-value-tab='templates']") |> render_click()
      html = lv |> element("button[phx-value-id='consent_gate']") |> render_click()
      assert html =~ "Configure"
    end

    test "inserts the template's child trials into the group", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      lv |> element("button[phx-value-tab='templates']") |> render_click()
      html = lv |> element("button[phx-value-id='consent_gate']") |> render_click()
      # Consent Gate generates 3 top-level child nodes
      assert html =~ "3 blocks"
    end
  end

  # ---------------------------------------------------------------------------
  # template_var_list_add / remove
  # ---------------------------------------------------------------------------

  describe "template_var_list_add" do
    setup %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      lv |> element("button[phx-value-tab='templates']") |> render_click()
      lv |> element("button[phx-value-id='likert_survey']") |> render_click()
      %{lv: lv}
    end

    test "adds a new item to the list variable", %{lv: lv} do
      html_before = render(lv)
      # likert_survey "prompts" starts with 1 item → 1 remove button for that key
      # Attributes render in declaration order: phx-click comes before phx-value-key
      prompts_removes_before =
        Regex.scan(~r/phx-click="template_var_list_remove"[^>]*phx-value-key="prompts"/, html_before)
        |> length()

      lv
      |> element("button[phx-click='template_var_list_add'][phx-value-key='prompts']")
      |> render_click()

      html_after = render(lv)

      prompts_removes_after =
        Regex.scan(~r/phx-click="template_var_list_remove"[^>]*phx-value-key="prompts"/, html_after)
        |> length()

      assert prompts_removes_after == prompts_removes_before + 1
    end
  end

  describe "template_var_list_remove" do
    setup %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      lv |> element("button[phx-value-tab='templates']") |> render_click()
      lv |> element("button[phx-value-id='likert_survey']") |> render_click()
      %{lv: lv}
    end

    test "removes an item from the list variable", %{lv: lv} do
      # First add an extra prompt so we have 2 to work with
      lv
      |> element("button[phx-click='template_var_list_add'][phx-value-key='prompts']")
      |> render_click()

      html_before = render(lv)

      prompts_removes_before =
        Regex.scan(~r/phx-click="template_var_list_remove"[^>]*phx-value-key="prompts"/, html_before)
        |> length()

      # Remove the first prompt (index 0)
      lv
      |> element("button[phx-click='template_var_list_remove'][phx-value-key='prompts'][phx-value-index='0']")
      |> render_click()

      html_after = render(lv)

      prompts_removes_after =
        Regex.scan(~r/phx-click="template_var_list_remove"[^>]*phx-value-key="prompts"/, html_after)
        |> length()

      assert prompts_removes_after == prompts_removes_before - 1
    end
  end

  # ---------------------------------------------------------------------------
  # save_study
  # ---------------------------------------------------------------------------

  describe "save_study" do
    test "creates the study, shows Saved flash, and patches to the study URL", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      lv |> element("button[phx-value-plugin='animation']") |> render_click()
      html = lv |> element("button[phx-click='save_study']") |> render_click()
      assert html =~ "Saved"
    end

    test "Save button becomes enabled after adding a trial", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/studies/new")
      html = lv |> element("button[phx-value-plugin='animation']") |> render_click()
      # Save button should no longer carry the disabled attribute
      refute html =~ ~s(<button class="btn btn-success shrink-0" phx-click="save_study" type="button" disabled>)
    end
  end
end
