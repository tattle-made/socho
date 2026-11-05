defmodule SochoWeb.PageController do
  use SochoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  # Browsers (mainly iOS Safari) auto-probe these paths on every page load
  # looking for a home-screen icon. Without a real icon to serve, respond
  # 204 (no content) instead of letting them 404 and pollute the 4xx error rate.
  def no_content(conn, _params) do
    send_resp(conn, 204, "")
  end
end
