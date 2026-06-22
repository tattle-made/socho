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

  def save_data(conn, %{"study_id" => study_id, "data" => trial_data}) when is_list(trial_data) do
    user_id = get_in(conn.assigns, [:current_scope, Access.key(:user), Access.key(:id)])
    study_id_int = String.to_integer(study_id)

    if Studies.has_submitted?(study_id_int, user_id) do
      json(conn, %{status: "already_submitted"})
    else
      case Studies.record_submission(study_id_int, user_id, trial_data) do
        {:ok, _} -> json(conn, %{status: "ok"})
        {:error, _} -> json(conn, %{status: "already_submitted"})
      end
    end
  end

  def export(conn, %{"study_id" => study_id}) do
    study = Studies.get_study_meta!(study_id)
    csv = Studies.export_submissions_csv(study_id)
    filename = study.title |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> then(&"#{&1}-submissions.csv")

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, csv)
  end

  defp authorize_study_access(%Scope{user: %User{role: :participant, client_id: p_client}}, study)
       when not is_nil(p_client) do
    if study.client_id == p_client, do: :ok, else: :forbidden
  end

  defp authorize_study_access(_scope, _study), do: :ok
end
