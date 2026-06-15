defmodule SochoWeb.ErrorJSONTest do
  use SochoWeb.ConnCase, async: true

  test "renders 404" do
    assert SochoWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert SochoWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
