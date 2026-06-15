defmodule SochoWeb.StudyController do
  use SochoWeb, :controller

  alias Socho.Studies.Study

  def show(conn, %{"study_id" => study_id}) do
    study = fetch_study(study_id)

    conn
    |> put_layout(html: {SochoWeb.Layouts, :study})
    |> render(:show, study: study)
  end

  def save_data(conn, %{"study_id" => study_id, "data" => csv_data}) do
    IO.inspect({study_id, String.slice(csv_data, 0, 200)}, label: "study response data")
    json(conn, %{status: "ok"})
  end

  # Placeholder: returns a hardcoded study struct.
  # Replace with a real DB lookup once the Study schema exists.
  defp fetch_study(_id) do
    %Study{
      id: "demo",
      title: "Demo Study",
      description: "A simple reaction time task built with jsPsych.",
      study: %{
        "type" => "reaction-time",
        "version" => "1.0",
        "author" => "Tattle",
        "trials" => 5
      },
      external_stylesheets: [
        "/vendor/jspsych/jspsych.min.css"
      ],
      external_scripts: [
        "/vendor/jspsych/jspsych.js",
        "/vendor/jspsych/html-keyboard-response.js",
        "/vendor/jspsych/survey-likert.js"
      ],
      inline_css: """
      body { background-color: #1a1a2e; }
      .jspsych-display-element { color: #eee; font-family: sans-serif; }
      """,
      inline_js: """
      function saveData(csvData) {
        const csrfToken = document.querySelector('meta[name="csrf-token"]').content;
        fetch(window.location.pathname + "/user-data", {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-csrf-token": csrfToken
          },
          body: JSON.stringify({ data: csvData })
        })
          .then(r => r.json())
          .then(result => console.log("Data saved:", result))
          .catch(err => console.error("Failed to save data:", err));
      }

      const jsPsych = initJsPsych({
        on_finish: function() {
          saveData(jsPsych.data.get().csv());
        }
      });

      const welcome = {
        type: jsPsychHtmlKeyboardResponse,
        stimulus: "<p>Welcome to the study.</p><p>Press any key to begin.</p>"
      };

      const trial = {
        type: jsPsychHtmlKeyboardResponse,
        stimulus: "<p style='font-size:80px;'>+</p>",
        choices: "NO_KEYS",
        trial_duration: 1000
      };

      const response = {
        type: jsPsychHtmlKeyboardResponse,
        stimulus: "<p style='font-size:80px; color: #e94560;'>●</p>",
        choices: " "
      };

      jsPsych.run([welcome, trial, response]);
      """
    }
  end
end
