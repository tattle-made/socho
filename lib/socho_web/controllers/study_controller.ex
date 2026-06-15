defmodule SochoWeb.StudyController do
  use SochoWeb, :controller

  alias Socho.Studies
  alias Socho.Studies.JsGenerator

  def show(conn, %{"study_id" => study_id}) do
    study = Studies.get_study!(study_id)

    conn
    |> assign(:page_title, study.title)
    |> assign(:external_stylesheets, JsGenerator.required_stylesheets(study))
    |> assign(:external_scripts, JsGenerator.required_scripts(study))
    |> assign(:inline_js, JsGenerator.generate_inline_js(study))
    |> put_layout(html: {SochoWeb.Layouts, :study})
    |> render(:show)
  end

  def save_data(conn, %{"study_id" => study_id, "data" => csv_data}) do
    IO.inspect({study_id, String.slice(csv_data, 0, 200)}, label: "study response data")
    json(conn, %{status: "ok"})
  end
end
