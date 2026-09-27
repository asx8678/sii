defmodule SiWeb.PageController do
  use SiWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
