defmodule SiWeb.ErrorJSONTest do
  use SiWeb.ConnCase, async: true

  test "renders 404" do
    assert SiWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert SiWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
