defmodule Socho.Studies.Study do
  @moduledoc """
  Prototype struct representing a jsPsych study to be served at /study/:id.
  In the real implementation this will be an Ecto schema backed by the database.
  """

  @enforce_keys [:id, :title]
  defstruct [
    :id,
    :title,
    :description,
    :study,
    :inline_css,
    :inline_js,
    external_scripts: [],
    external_stylesheets: []
  ]
end
