defmodule Socho.Accounts.UserSMSNotifier do
  alias Socho.SMS

  @doc """
  Delivers a login OTP to the user's phone number.
  """
  def deliver_login_otp(user, otp) do
    SMS.send_sms(user.phone_number, "Your Socho login code is #{otp}. It expires in 10 minutes.")
  end

  @doc """
  Delivers a registration OTP to the user's phone number.
  """
  def deliver_registration_otp(user, otp) do
    SMS.send_sms(
      user.phone_number,
      "Your Socho verification code is #{otp}. It expires in 10 minutes."
    )
  end
end
