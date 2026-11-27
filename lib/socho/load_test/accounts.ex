defmodule Socho.LoadTest.Accounts do
  @moduledoc """
  The participant accounts the load test signs in with.

  The seed and the scenario agree on them by convention:
  account 1 is lt-000001@loadtest.socho.local,
  account 100 is lt-000100@loadtest.socho.local,... so on and
  every account shares one password.
  """

  @password "loadtest-password"
  @email_domain "loadtest.socho.local"
  @default_count 5_000

  def password, do: @password

  def email_domain, do: @email_domain

  def default_count, do: @default_count

  # 1 -> "lt-000001@loadtest.socho.local"
  def email(number) do
    "lt-#{String.pad_leading(Integer.to_string(number), 6, "0")}@#{@email_domain}"
  end
end
