defmodule SochoWeb.Router do
  use SochoWeb, :router

  import SochoWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SochoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SochoWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/study/:study_id", StudyController, :show
    post "/study/:study_id/user-data", StudyController, :save_data
    get "/studies/:study_id/export", StudyController, :export
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:socho, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SochoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", SochoWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{SochoWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    live_session :require_admin_or_manager,
      on_mount: [
        {SochoWeb.UserAuth, :require_authenticated},
        {SochoWeb.UserAuth, :require_admin_or_manager}
      ] do
      live "/users", UserLive.Management, :index
      live "/studies", StudyLive.Index, :index
      live "/studies/new", StudyLive.Builder, :new
      live "/studies/:id/edit", StudyLive.Builder, :edit
      live "/studies/:id/settings", StudyLive.Settings, :edit
      live "/clients", ClientLive.Management, :index
    end

    live_session :require_participant,
      on_mount: [{SochoWeb.UserAuth, :require_participant}] do
      live "/dashboard", StudyLive.Dashboard, :index
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", SochoWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{SochoWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  scope "/", SochoWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_admin_or_manager_detail,
      on_mount: [
        {SochoWeb.UserAuth, :require_authenticated},
        {SochoWeb.UserAuth, :require_admin_or_manager}
      ] do
      live "/users/:id", UserLive.Show, :show
      live "/users/:id/edit", UserLive.Edit, :edit
      live "/clients/:id", ClientLive.Show, :show
      live "/clients/:id/edit", ClientLive.Edit, :edit
    end
  end
end
