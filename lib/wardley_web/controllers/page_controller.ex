defmodule WardleyWeb.PageController do
  use WardleyWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
