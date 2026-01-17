defmodule WardleyWeb.GameplayController do
  use WardleyWeb, :controller

  def show(conn, _params) do
    render(conn, :gameplay)
  end
end
