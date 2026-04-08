defmodule Wardley.MCP.ServerTest do
  use Wardley.DataCase, async: true

  alias Wardley.MCP.Server

  defp call(input_line) do
    {:ok, input} = StringIO.open(input_line <> "\n")
    {:ok, output} = StringIO.open("")

    Server.start(input: input, output: output)

    {_in, out} = StringIO.contents(output)
    StringIO.close(input)
    StringIO.close(output)

    out
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end

  describe "initialize" do
    test "responds with server info and capabilities" do
      [response] =
        call(
          Jason.encode!(%{
            jsonrpc: "2.0",
            id: 1,
            method: "initialize",
            params: %{protocolVersion: "2024-11-05"}
          })
        )

      assert response["id"] == 1
      assert response["result"]["serverInfo"]["name"] == "wardley-mcp"
      assert response["result"]["capabilities"]["tools"] == %{}
      assert response["result"]["protocolVersion"] == "2024-11-05"
    end
  end

  describe "tools/list" do
    test "returns tool definitions" do
      [response] =
        call(Jason.encode!(%{jsonrpc: "2.0", id: 2, method: "tools/list"}))

      assert response["id"] == 2
      tools = response["result"]["tools"]
      assert is_list(tools)

      names = Enum.map(tools, & &1["name"])
      assert "get_map" in names
      assert "create_node" in names
      assert "connect_nodes" in names
    end
  end

  describe "tools/call" do
    test "creates a node via tool call" do
      [response] =
        call(
          Jason.encode!(%{
            jsonrpc: "2.0",
            id: 3,
            method: "tools/call",
            params: %{
              name: "create_node",
              arguments: %{text: "Test Component", x_pct: 50.0, y_pct: 30.0}
            }
          })
        )

      assert response["id"] == 3
      [content] = response["result"]["content"]
      assert content["type"] == "text"

      node = Jason.decode!(content["text"])
      assert node["text"] == "Test Component"
      assert node["id"] != nil
    end

    test "returns error for unknown tool" do
      [response] =
        call(
          Jason.encode!(%{
            jsonrpc: "2.0",
            id: 4,
            method: "tools/call",
            params: %{name: "nonexistent", arguments: %{}}
          })
        )

      assert response["result"]["isError"] == true
    end

    test "returns error for not-found entity" do
      [response] =
        call(
          Jason.encode!(%{
            jsonrpc: "2.0",
            id: 5,
            method: "tools/call",
            params: %{name: "delete_node", arguments: %{node_id: 999_999}}
          })
        )

      assert response["result"]["isError"] == true
      [content] = response["result"]["content"]
      assert content["text"] =~ "Not found"
    end
  end

  describe "notifications" do
    test "notifications/initialized is silently accepted" do
      results =
        call(
          Jason.encode!(%{jsonrpc: "2.0", method: "notifications/initialized"})
        )

      assert results == []
    end
  end

  describe "error handling" do
    test "returns parse error for invalid JSON" do
      [response] = call("not valid json")

      assert response["error"]["code"] == -32700
      assert response["error"]["message"] == "Parse error"
    end

    test "returns method not found for unknown method" do
      [response] =
        call(Jason.encode!(%{jsonrpc: "2.0", id: 6, method: "unknown/method"}))

      assert response["error"]["code"] == -32601
    end
  end
end
