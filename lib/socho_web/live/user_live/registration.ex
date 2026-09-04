defmodule SochoWeb.UserLive.Registration do
  use SochoWeb, :live_view

  alias Socho.Accounts
  alias Socho.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            Register for an account
            <:subtitle>
              Already registered?
              <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
                Log in
              </.link>
              to your account now.
            </:subtitle>
          </.header>
        </div>

        <div class="flex rounded-lg border border-base-300 mb-6 overflow-hidden">
          <button
            type="button"
            phx-click="set_method"
            phx-value-method="email"
            class={[
              "flex-1 py-2 text-sm font-medium transition-colors",
              @verification_method == :email && "bg-primary text-primary-content",
              @verification_method != :email && "bg-base-100 text-base-content hover:bg-base-200"
            ]}
          >
            Email
          </button>
          <button
            type="button"
            phx-click="set_method"
            phx-value-method="sms"
            class={[
              "flex-1 py-2 text-sm font-medium transition-colors",
              @verification_method == :sms && "bg-primary text-primary-content",
              @verification_method != :sms && "bg-base-100 text-base-content hover:bg-base-200"
            ]}
          >
            Phone (SMS)
          </button>
        </div>

        <.form
          :if={@verification_method == :email}
          for={@form}
          id="registration_form_email"
          phx-submit="save"
          phx-change="validate"
        >
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />
          <.button phx-disable-with="Creating account..." class="btn btn-primary w-full">
            Create an account
          </.button>
        </.form>

        <.form
          :if={@verification_method == :sms}
          for={@sms_form}
          id="registration_form_sms"
          phx-submit="save_sms"
          phx-change="validate_sms"
        >
          <.input
            field={@sms_form[:phone_number]}
            type="tel"
            label="Phone number"
            placeholder="+919876543210"
            autocomplete="tel"
            required
            phx-mounted={JS.focus()}
          />
          <p class="text-xs text-base-content/60 mt-1 mb-4">
            Enter your number in international format (e.g. +91 for India).
          </p>
          <.button phx-disable-with="Sending code..." class="btn btn-primary w-full">
            Send verification code
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: SochoWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    email_changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)
    sms_changeset = Accounts.change_user_sms_registration(%User{}, %{}, validate_unique: false)

    {:ok,
     socket
     |> assign(verification_method: :email)
     |> assign_form(email_changeset)
     |> assign_sms_form(sms_changeset)}
  end

  @impl true
  def handle_event("set_method", %{"method" => method}, socket) do
    {:noreply, assign(socket, verification_method: String.to_existing_atom(method))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{user.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("save_sms", %{"user" => user_params}, socket) do
    case Accounts.register_user_with_sms(user_params) do
      {:ok, user} ->
        :ok = Accounts.deliver_sms_registration_instructions(user)
        encoded_phone = Base.url_encode64(user.phone_number, padding: false)

        {:noreply,
         socket
         |> put_flash(:info, "A verification code was sent to #{user.phone_number}.")
         |> push_navigate(to: ~p"/users/log-in/sms?phone=#{encoded_phone}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_sms_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_email(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event("validate_sms", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_sms_registration(%User{}, user_params, validate_unique: false)
    {:noreply, assign_sms_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset, as: "user"))
  end

  defp assign_sms_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, sms_form: to_form(changeset, as: "user"))
  end
end
