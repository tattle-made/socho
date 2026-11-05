defmodule Socho.SMS do
  @moduledoc """
  SMS dispatcher. Delegates to the configured adapter.

  Configure adapter per environment:

      config :socho, Socho.SMS, adapter: Socho.SMS.Adapters.Local
  """

  def send_otp(to, var) do
    adapter().send_otp(to, var)
  end

  def send_forget_password(to, var) do
    adapter().send_forget_password(to, var)
  end

  defp adapter do
    Application.get_env(:socho, __MODULE__, [])
    |> Keyword.get(:adapter, Socho.SMS.Adapters.Local)
  end
end
