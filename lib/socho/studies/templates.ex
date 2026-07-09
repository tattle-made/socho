defmodule Socho.Studies.Templates do
  @moduledoc "Registry of pre-built study templates. Each template lives in its own module under Templates/."

  alias Socho.Studies.Templates.{
    ConsentGate,
    ConsentAndInstructions,
    SimpleSurvey,
    ImageSwipeTask,
    Iat
  }

  def all do
    [
      ConsentGate.definition(),
      ConsentAndInstructions.definition(),
      SimpleSurvey.definition(),
      ImageSwipeTask.definition(),
      Iat.definition()
    ]
  end

  def get(id), do: Enum.find(all(), &(&1.id == id))
end
