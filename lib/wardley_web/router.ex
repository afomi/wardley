defmodule WardleyWeb.Router do
  use WardleyWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WardleyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_current_path
  end

  defp put_current_path(conn, _opts) do
    assign(conn, :current_path, conn.request_path)
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", WardleyWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/map", MapController, :show
    get "/search", SearchPageController, :index
    get "/personas", PersonasPageController, :index
    get "/personas/:id", PersonasPageController, :show
    get "/gameplay", GameplayController, :show
  end

  # Other scopes may use custom stacks.
  scope "/api", WardleyWeb do
    pipe_through :api

    # Map and node/edge operations
    get "/map", MapAPIController, :map
    get "/maps", MapAPIController, :list_maps
    get "/maps/:id", MapAPIController, :show_map
    post "/nodes", MapAPIController, :create_node
    patch "/nodes/:id", MapAPIController, :update_node
    delete "/nodes/:id", MapAPIController, :delete_node
    post "/edges", MapAPIController, :create_edge
    patch "/edges/:id", MapAPIController, :update_edge
    delete "/edges/:id", MapAPIController, :delete_edge

    # Search
    get "/search", SearchController, :search
    get "/categories", SearchController, :categories
    get "/categories/:category", SearchController, :by_category
    get "/tags", SearchController, :tags
    get "/tags/:tag", SearchController, :by_tag

    # Personas
    get "/personas", PersonasController, :index
    get "/personas/:id", PersonasController, :show
    post "/personas", PersonasController, :create
    patch "/personas/:id", PersonasController, :update
    delete "/personas/:id", PersonasController, :delete
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:wardley, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WardleyWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
