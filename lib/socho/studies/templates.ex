defmodule Socho.Studies.Templates do
  @moduledoc "Registry of pre-built study templates. Each template lives in its own module under Templates/."

  alias Socho.Studies.Templates.{
    ConsentGate,
    ConsentAndInstructions,
    SimpleSurvey,
    LikertSurvey,
    MultiChoiceGroup,
    ImageSwipeTask,
    PairwiseImageCompare,
    Iat
  }

  def all do
    [
      ConsentGate.definition(),
      ConsentAndInstructions.definition(),
      SimpleSurvey.definition(),
      LikertSurvey.definition(),
      MultiChoiceGroup.definition(),
      ImageSwipeTask.definition(),
      PairwiseImageCompare.definition(),
      Iat.definition()
    ]
  end

  def get(id), do: Enum.find(all(), &(&1.id == id))
end
