defmodule Socho.SMS.Adapters.Local do
  @moduledoc """
  Development SMS adapter. Logs messages instead of sending real SMS.

  Enabled by default in dev. Check your application logs to see OTP codes.
  """

  @behaviour Socho.SMS.Adapter

  require Logger

  @impl true
  def send_otp(to, var) do
    Logger.debug("[SMS Local] OTP to #{to} | vars: #{inspect(var)}")
    :ok
  end

  @impl true
  def send_forget_password(to, var) do
    Logger.debug("[SMS Local] Forgot-password SMS to #{to} | vars: #{inspect(var)}")
    :ok
  end
end
