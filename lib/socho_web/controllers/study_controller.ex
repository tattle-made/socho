defmodule SochoWeb.StudyController do
  use SochoWeb, :controller

  alias Socho.Accounts.{Scope, User}
  alias Socho.Studies
  alias Socho.Studies.JsGenerator

  def show(conn, %{"study_id" => study_id}) do
    study = Studies.get_study!(study_id)

    case authorize_study_access(conn.assigns.current_scope, study) do
      :ok ->
        conn
        |> assign(:page_title, study.title)
        |> assign(:external_stylesheets, JsGenerator.required_stylesheets(study))
        |> assign(:external_scripts, JsGenerator.required_scripts(study))
        |> assign(:inline_js, JsGenerator.generate_inline_js(study))
        |> put_layout(html: {SochoWeb.Layouts, :study})
        |> render(:show)

      :forbidden ->
        conn
        |> put_flash(:error, "You don't have access to this study.")
        |> redirect(to: ~p"/dashboard")
    end
  end

  def save_data(conn, %{"study_id" => study_id, "data" => csv_data}) do
    IO.inspect({study_id, String.slice(csv_data, 0, 200)}, label: "study response data")
    json(conn, %{status: "ok"})
  end

  defp authorize_study_access(%Scope{user: %User{role: :participant, client_id: p_client}}, study)
       when not is_nil(p_client) do
    if study.client_id == p_client, do: :ok, else: :forbidden
  end

  defp authorize_study_access(_scope, _study), do: :ok
end
