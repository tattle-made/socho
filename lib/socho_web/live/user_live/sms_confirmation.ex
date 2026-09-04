defmodule SochoWeb.UserLive.SMSConfirmation do
  use SochoWeb, :live_view

  alias Socho.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            Enter your verification code
            <:subtitle>
              We sent a 6-digit code to <strong>{@phone_number}</strong>.
              It expires in 10 minutes.
            </:subtitle>
          </.header>
        </div>

        <.form
          for={@form}
          id="sms_confirmation_form"
          phx-submit="submit"
          phx-change="validate"
          action={~p"/users/log-in?_action=sms_confirmed"}
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name={@form[:phone_number].name} value={@form[:phone_number].value} />
          <.input
            field={@form[:otp]}
            type="text"
            label="Verification code"
            placeholder="123456"
            inputmode="numeric"
            autocomplete="one-time-code"
            maxlength="6"
            phx-mounted={JS.focus()}
          />
          <.button phx-disable-with="Verifying..." class="btn btn-primary w-full mt-4">
            Verify and log in <span aria-hidden="true">→</span>
          </.button>
        </.form>

        <div class="mt-6 text-center">
          <.link
            href={~p"/users/log-in"}
            class="text-sm text-base-content/60 hover:underline"
          >
            Use email instead
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"phone" => encoded_phone}, _session, socket) do
    case Base.url_decode64(encoded_phone, padding: false) do
      {:ok, phone_number} ->
        form = to_form(%{"phone_number" => phone_number, "otp" => ""}, as: "user")
        {:ok, assign(socket, phone_number: phone_number, form: form, trigger_submit: false)}

      :error ->
        {:ok,
         socket
         |> put_flash(:error, "Invalid verification link.")
         |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> put_flash(:error, "Missing phone number.")
     |> push_navigate(to: ~p"/users/log-in")}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    form = to_form(params, as: "user")
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("submit", %{"user" => %{"otp" => otp} = params}, socket) do
    otp_clean = String.trim(otp)

    if String.length(otp_clean) == 6 && String.match?(otp_clean, ~r/^\d{6}$/) do
      {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
    else
      form =
        to_form(
          Map.put(params, "otp_error", "must be 6 digits"),
          as: "user"
        )

      {:noreply,
       socket
       |> put_flash(:error, "Please enter a valid 6-digit code.")
       |> assign(form: form)}
    end
  end
end
