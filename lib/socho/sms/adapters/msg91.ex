defmodule Socho.SMS.Adapters.Msg91 do
  @moduledoc """
  Msg91 SMS adapter using their Flow API.

  Required config:

      config :socho, Socho.SMS,
        adapter: Socho.SMS.Adapters.Msg91,
        auth_key: "your_msg91_auth_key"

  The OTP template in Msg91 must have a `##OTP##` variable.
  Phone numbers must be in E.164 format (e.g. "919876543210").
  """

  @behaviour Socho.SMS.Adapter

  # Refer to console on msg91 for this (https://control.msg91.com/app/m/l/sms/templates)
  @template_otp_verification "6ac4c40e6c8cb16130015168"

  defp base_req do
    config = Application.get_env(:socho, Socho.SMS, [])
    auth_key = Keyword.get(config, :auth_key)

    Req.new(
      base_url: "https://control.msg91.com/api/v5",
      headers: [
        {"accept", "application/json"},
        {"authkey", auth_key}
      ]
    )
  end

  @doc """
  Sends an SMS to user with an OTP in it.

  For this to work correctly, a template should be whitelisted on a DLT provider and this template needs to be added on the SMS vendor like MSG91. The expected shape of var is %{"username" => "string", "otp" => "4_digit_OTP"}
  """
  @impl true
  def send_otp(mobile, var) do
    username = var["username"] || "user"
    otp = var["OTP"]

    data = %{
      "template_id" => @template_otp_verification,
      "short_url" => "0",
      "recipients" => [%{"mobiles" => mobile, "username" => username, "otp" => otp}]
    }

    case Req.post(base_req(), url: "/flow", json: data) do
      {:ok, %Req.Response{status: status}} when status in 200..299 -> :ok
      {:ok, %Req.Response{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def send_forget_password(mobile, var) do
    :ok
  end
end
