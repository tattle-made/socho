defmodule Socho.SMS.Adapters.Msg91 do
  @moduledoc """
  Msg91 SMS adapter using their Flow API.

  Required config:

      config :socho, Socho.SMS,
        adapter: Socho.SMS.Adapters.Msg91,
        auth_key: "your_msg91_auth_key",
        template_id: "your_otp_template_id"

  The OTP template in Msg91 must have a `##OTP##` variable.
  Phone numbers must be in E.164 format (e.g. "919876543210").
  """

  @behaviour Socho.SMS.Adapter

  @api_url "https://control.msg91.com/api/v5/otp"

  @impl true
  def send_sms(to, otp) do
    config = Application.get_env(:socho, Socho.SMS, [])
    auth_key = Keyword.fetch!(config, :auth_key)
    template_id = Keyword.fetch!(config, :template_id)

    params = %{
      "authkey" => auth_key,
      "template_id" => template_id,
      "mobile" => to,
      "otp" => otp
    }

    case Req.post(@api_url, json: params) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
