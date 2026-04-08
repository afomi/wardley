defmodule Wardley.MCP.Server do
  @moduledoc """
  MCP server over stdio using JSON-RPC 2.0.

  Reads JSON lines from an input device, dispatches to tool handlers,
  writes JSON-RPC responses to an output device. Defaults to
  stdio but accepts custom IO devices for testing.
  """
  alias Wardley.MCP.Tools

  @server_info %{
    name: "wardley-mcp",
    version: "0.1.0"
  }

  @capabilities %{
    tools: %{}
  }

  def start(opts \\ []) do
    input = opts[:input] || :stdio
    output = opts[:output] || :stdio

    loop(input, output)
  end

  defp loop(input, output) do
    case IO.read(input, :line) do
      :eof ->
        :ok

      {:error, _reason} ->
        :ok

      line ->
        line
        |> String.trim()
        |> handle_line(output)

        loop(input, output)
    end
  end

  defp handle_line("", _output), do: :ok

  defp handle_line(line, output) do
    case Jason.decode(line) do
      {:ok, msg} ->
        handle_message(msg, output)

      {:error, _} ->
        send_error(output, nil, -32700, "Parse error")
    end
  end

  defp handle_message(%{"method" => "initialize", "id" => id}, output) do
    send_result(output, id, %{
      protocolVersion: "2024-11-05",
      serverInfo: @server_info,
      capabilities: @capabilities
    })
  end

  defp handle_message(%{"method" => "notifications/initialized"}, _output) do
    :ok
  end

  defp handle_message(%{"method" => "tools/list", "id" => id}, output) do
    send_result(output, id, %{tools: Tools.definitions()})
  end

  defp handle_message(%{"method" => "tools/call", "id" => id, "params" => params}, output) do
    tool_name = params["name"]
    arguments = params["arguments"] || %{}

    try do
      case Tools.handle(tool_name, arguments) do
        {:ok, text} ->
          send_result(output, id, %{
            content: [%{type: "text", text: text}]
          })

        {:error, text} ->
          send_result(output, id, %{
            content: [%{type: "text", text: text}],
            isError: true
          })
      end
    rescue
      Ecto.NoResultsError ->
        send_result(output, id, %{
          content: [%{type: "text", text: "Not found: #{tool_name} with given ID"}],
          isError: true
        })

      e ->
        send_result(output, id, %{
          content: [%{type: "text", text: "Error: #{Exception.message(e)}"}],
          isError: true
        })
    end
  end

  defp handle_message(%{"id" => id}, output) do
    send_error(output, id, -32601, "Method not found")
  end

  defp handle_message(_msg, _output), do: :ok

  defp send_result(output, id, result) do
    response = %{jsonrpc: "2.0", id: id, result: result}
    write_json(output, response)
  end

  defp send_error(output, id, code, message) do
    response = %{jsonrpc: "2.0", id: id, error: %{code: code, message: message}}
    write_json(output, response)
  end

  defp write_json(output, data) do
    IO.puts(output, Jason.encode!(data))
  end
end
