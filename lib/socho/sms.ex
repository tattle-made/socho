defmodule Socho.SMS do
  @moduledoc """
  SMS dispatcher. Delegates to the configured adapter.

  Configure adapter per environment:

      config :socho, Socho.SMS, adapter: Socho.SMS.Adapters.Local
  """

  @doc """
  Sends an SMS message to the given phone number.
  """
  def send_sms(to, body) do
    adapter().send_sms(to, body)
  end

  defp adapter do
    Application.get_env(:socho, __MODULE__, [])
    |> Keyword.get(:adapter, Socho.SMS.Adapters.Local)
  end
end
