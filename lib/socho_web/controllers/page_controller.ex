defmodule SochoWeb.PageController do
  use SochoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
