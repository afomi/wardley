defmodule WardleyWeb.GameplayController do
  use WardleyWeb, :controller

  def show(conn, _params) do
    conn
    |> assign(:page_title, "Strategy Gameplay")
    |> assign(:page_description, "Explore strategic gameplay patterns for Wardley Mapping. Learn climatic patterns, doctrine, and leadership moves to navigate competitive landscapes.")
    |> render(:gameplay)
  end
end
