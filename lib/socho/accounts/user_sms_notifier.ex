defmodule Socho.Accounts.UserSMSNotifier do
  alias Socho.SMS

  @doc """
  Delivers a login OTP to the user's phone number.
  """
  def deliver_login_otp(user, otp) do
    SMS.send_otp(user.phone_number, %{"OTP" => otp})
  end

  @doc """
  Delivers a registration OTP to the user's phone number.
  """
  def deliver_registration_otp(user, otp) do
    SMS.send_otp(user.phone_number, %{"OTP" => otp})
  end
end
