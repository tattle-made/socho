defmodule Socho.SMS.Adapter do
  @moduledoc """
  Behaviour for SMS delivery adapters.

  Implement this to swap SMS vendors without touching application code.
  Configure the active adapter in your environment config:

      config :socho, Socho.SMS, adapter: Socho.SMS.Adapters.Msg91
  """

  @callback send_otp(to :: String.t(), var :: map()) :: :ok | {:error, term()}

  @callback send_forget_password(to :: String.t(), var :: map()) :: :ok | {:error, term()}
end
