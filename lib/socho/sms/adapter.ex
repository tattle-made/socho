defmodule Socho.SMS.Adapter do
  @moduledoc """
  Behaviour for SMS delivery adapters.

  Implement this to swap SMS vendors without touching application code.
  Configure the active adapter in your environment config:

      config :socho, Socho.SMS, adapter: Socho.SMS.Adapters.Msg91
  """

  @callback send_sms(to :: String.t(), body :: String.t()) :: :ok | {:error, term()}
end
