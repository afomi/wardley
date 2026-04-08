defmodule Mix.Tasks.Wardley.Mcp do
  @moduledoc """
  Starts the Wardley MCP server over stdio.

  Used by Claude Code and other MCP-capable LLM clients.

      mix wardley.mcp
  """
  use Mix.Task

  @shortdoc "Start the Wardley MCP server (stdio)"

  @impl Mix.Task
  def run(_args) do
    # Redirect logger to stderr so stdout stays clean for JSON-RPC
    Logger.configure_backend(:console, device: :standard_error)

    Mix.Task.run("app.start")

    Wardley.MCP.Server.start()
  end
end
