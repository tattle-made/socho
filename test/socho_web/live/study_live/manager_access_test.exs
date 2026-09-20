defmodule SochoWeb.StudyLive.ManagerAccessTest do
  use SochoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Socho.Accounts.UserAdmin
  alias Socho.Clients
  alias Socho.Studies
  alias Socho.Repo
  alias Ecto.Changeset

  setup %{conn: conn} do
    {:ok, client_a} = Clients.create_client(%{name: "Client Alpha #{System.unique_integer()}"})
    {:ok, client_b} = Clients.create_client(%{name: "Client Beta #{System.unique_integer()}"})

    {:ok, manager_a} =
      UserAdmin.create_user(
        "manager_a_#{System.unique_integer()}@example.com",
        "password123!",
        :manager
      )

    manager_a =
      manager_a
      |> Changeset.change(client_id: client_a.id)
      |> Repo.update!()

    {:ok, manager_unassigned} =
      UserAdmin.create_user(
        "manager_un_#{System.unique_integer()}@example.com",
        "password123!",
        :manager
      )

    {:ok, admin} =
      UserAdmin.create_user(
        "admin_#{System.unique_integer()}@example.com",
        "password123!",
        :admin
      )

    {:ok, study_a} =
      Studies.create_study_with_trials("Study for Client A", client_a.id, [
        %{node_type: "trial", plugin: "animation", config: %{}, extensions: %{}, children: []}
      ])

    {:ok, study_b} =
      Studies.create_study_with_trials("Study for Client B", client_b.id, [
        %{node_type: "trial", plugin: "animation", config: %{}, extensions: %{}, children: []}
      ])

    {:ok, study_unassigned} =
      Studies.create_study_with_trials("Unassigned Study", nil, [
        %{node_type: "trial", plugin: "animation", config: %{}, extensions: %{}, children: []}
      ])

    %{
      conn: conn,
      client_a: client_a,
      client_b: client_b,
      manager_a: manager_a,
      manager_unassigned: manager_unassigned,
      admin: admin,
      study_a: study_a,
      study_b: study_b,
      study_unassigned: study_unassigned
    }
  end

  describe "studies index RBAC" do
    test "manager assigned to client A sees only study A", %{
      conn: conn,
      manager_a: manager_a,
      study_a: study_a,
      study_b: study_b,
      study_unassigned: study_unassigned
    } do
      conn = log_in_user(conn, manager_a)
      {:ok, _lv, html} = live(conn, ~p"/studies")

      assert html =~ study_a.title
      refute html =~ study_b.title
      refute html =~ study_unassigned.title
    end

    test "manager with no client assigned sees no studies", %{
      conn: conn,
      manager_unassigned: manager_unassigned,
      study_a: study_a,
      study_b: study_b,
      study_unassigned: study_unassigned
    } do
      conn = log_in_user(conn, manager_unassigned)
      {:ok, _lv, html} = live(conn, ~p"/studies")

      assert html =~ "No studies yet."
      refute html =~ study_a.title
      refute html =~ study_b.title
      refute html =~ study_unassigned.title
    end

    test "admin sees all studies", %{
      conn: conn,
      admin: admin,
      study_a: study_a,
      study_b: study_b,
      study_unassigned: study_unassigned
    } do
      conn = log_in_user(conn, admin)
      {:ok, _lv, html} = live(conn, ~p"/studies")

      assert html =~ study_a.title
      assert html =~ study_b.title
      assert html =~ study_unassigned.title
    end

    test "manager cannot delete study from another client", %{
      conn: conn,
      manager_a: manager_a,
      study_b: study_b
    } do
      conn = log_in_user(conn, manager_a)
      {:ok, lv, _html} = live(conn, ~p"/studies")

      html = render_hook(lv, "delete_study", %{"id" => "#{study_b.id}"})
      assert html =~ "You are not authorized to delete this study" or html =~ "not authorized"
      assert Studies.get_study_meta!(study_b.id) != nil
    end
  end

  describe "study builder RBAC" do
    test "manager assigned to client A can edit study A", %{
      conn: conn,
      manager_a: manager_a,
      study_a: study_a
    } do
      conn = log_in_user(conn, manager_a)
      {:ok, _lv, html} = live(conn, ~p"/studies/#{study_a.id}/edit")
      assert html =~ "Study Builder"
      assert html =~ "animation"
    end

    test "manager assigned to client A cannot edit study B", %{
      conn: conn,
      manager_a: manager_a,
      study_b: study_b
    } do
      conn = log_in_user(conn, manager_a)

      assert {:error, {:live_redirect, %{to: "/studies", flash: %{"error" => _msg}}}} =
               live(conn, ~p"/studies/#{study_b.id}/edit")
    end

    test "manager assigned to client A cannot edit unassigned study", %{
      conn: conn,
      manager_a: manager_a,
      study_unassigned: study_unassigned
    } do
      conn = log_in_user(conn, manager_a)

      assert {:error, {:live_redirect, %{to: "/studies", flash: %{"error" => _msg}}}} =
               live(conn, ~p"/studies/#{study_unassigned.id}/edit")
    end

    test "admin can edit any study", %{
      conn: conn,
      admin: admin,
      study_a: study_a,
      study_b: study_b,
      study_unassigned: study_unassigned
    } do
      conn = log_in_user(conn, admin)
      {:ok, _lv, html_a} = live(conn, ~p"/studies/#{study_a.id}/edit")
      assert html_a =~ "Study Builder"
      assert html_a =~ "animation"

      {:ok, _lv, html_b} = live(conn, ~p"/studies/#{study_b.id}/edit")
      assert html_b =~ "Study Builder"
      assert html_b =~ "animation"

      {:ok, _lv, html_u} = live(conn, ~p"/studies/#{study_unassigned.id}/edit")
      assert html_u =~ "Study Builder"
      assert html_u =~ "animation"
    end
  end

  describe "study settings RBAC" do
    test "manager assigned to client A can access settings for study A", %{
      conn: conn,
      manager_a: manager_a,
      study_a: study_a
    } do
      conn = log_in_user(conn, manager_a)
      {:ok, _lv, html} = live(conn, ~p"/studies/#{study_a.id}/settings")
      assert html =~ "Study Settings"
    end

    test "manager assigned to client A cannot access settings for study B", %{
      conn: conn,
      manager_a: manager_a,
      study_b: study_b
    } do
      conn = log_in_user(conn, manager_a)

      assert {:error, {:redirect, %{to: "/studies", flash: %{"error" => _msg}}}} =
               live(conn, ~p"/studies/#{study_b.id}/settings")
    end
  end

  describe "study show / preview RBAC" do
    test "manager assigned to client A can view study A", %{
      conn: conn,
      manager_a: manager_a,
      study_a: study_a
    } do
      conn = log_in_user(conn, manager_a)
      conn = get(conn, ~p"/study/#{study_a.id}")
      assert html_response(conn, 200) =~ study_a.title
    end

    test "manager assigned to client A cannot view study B", %{
      conn: conn,
      manager_a: manager_a,
      study_b: study_b
    } do
      conn = log_in_user(conn, manager_a)
      conn = get(conn, ~p"/study/#{study_b.id}")
      assert redirected_to(conn) == "/dashboard"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "don't have access"
    end
  end
end
