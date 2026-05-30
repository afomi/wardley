defmodule WardleyWeb.Router do
  use WardleyWeb, :router

  import WardleyWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WardleyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug :put_current_path
  end

  defp put_current_path(conn, _opts) do
    assign(conn, :current_path, conn.request_path)
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug WardleyWeb.Plugs.ApiTokenAuth, optional: true
  end

  scope "/", WardleyWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/maps", MapController, :index
    get "/map", MapController, :show
    get "/search", SearchPageController, :index
    get "/personas", PersonasPageController, :index
    get "/personas/:id", PersonasPageController, :show
    get "/gameplay", GameplayController, :show
    get "/developers", DevelopersController, :index
  end

  scope "/auth", WardleyWeb do
    pipe_through :browser

    get "/:provider", OAuthController, :request
    get "/:provider/callback", OAuthController, :callback
  end

  # Other scopes may use custom stacks.
  scope "/api", WardleyWeb do
    pipe_through :api

    get "/me", ApiTokenController, :show

    # Map and node/edge operations
    get "/map", MapAPIController, :map
    get "/maps", MapAPIController, :list_maps
    post "/maps", MapAPIController, :create_map
    get "/maps/:id", MapAPIController, :show_map
    patch "/maps/:id", MapAPIController, :update_map
    delete "/maps/:id", MapAPIController, :delete_map
    get "/maps/:id/dsl", MapAPIController, :map_dsl
    get "/maps/:id/svg", MapAPIController, :map_svg
    post "/nodes", MapAPIController, :create_node
    patch "/nodes/:id", MapAPIController, :update_node
    delete "/nodes/:id", MapAPIController, :delete_node
    post "/edges", MapAPIController, :create_edge
    patch "/edges/:id", MapAPIController, :update_edge
    delete "/edges/:id", MapAPIController, :delete_edge

    # Fragments
    get "/fragments", MapAPIController, :list_fragments
    get "/fragments/:id", MapAPIController, :show_fragment
    post "/fragments", MapAPIController, :create_fragment
    delete "/fragments/:id", MapAPIController, :delete_fragment
    post "/fragments/:id/invoke", MapAPIController, :invoke_fragment

    # Search
    get "/suggestions", SearchController, :suggestions
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

  ## Authentication routes

  scope "/", WardleyWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{WardleyWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
    post "/api/tokens", ApiTokenController, :create
  end

  scope "/", WardleyWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{WardleyWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/login", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    get "/users/log-in", UserSessionController, :new
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
