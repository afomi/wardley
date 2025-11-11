defmodule WardleyWeb.Router do
  use WardleyWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WardleyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", WardleyWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/map", MapController, :show
  end

  # Other scopes may use custom stacks.
  scope "/api", WardleyWeb do
    pipe_through :api

    get "/map", MapAPIController, :map
    post "/nodes", MapAPIController, :create_node
    patch "/nodes/:id", MapAPIController, :update_node
    delete "/nodes/:id", MapAPIController, :delete_node
    post "/edges", MapAPIController, :create_edge
    patch "/edges/:id", MapAPIController, :update_edge
    delete "/edges/:id", MapAPIController, :delete_edge
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
