defmodule Wardley.MapsTest do
  use Wardley.DataCase, async: true

  alias Wardley.Maps
  alias Wardley.Maps.{Map, Node, Edge}

  describe "maps" do
    test "get_or_create_default_map/0 creates a map if none exists" do
      map = Maps.get_or_create_default_map()

      assert %Map{} = map
      assert map.name == "Default Map"
      assert map.id != nil
    end

    test "get_or_create_default_map/0 returns existing map on subsequent calls" do
      map1 = Maps.get_or_create_default_map()
      map2 = Maps.get_or_create_default_map()

      assert map1.id == map2.id
    end

    test "get_map!/1 returns the map with given id" do
      map = Maps.get_or_create_default_map()
      fetched = Maps.get_map!(map.id)

      assert fetched.id == map.id
      assert fetched.name == map.name
    end
  end

  describe "nodes" do
    setup do
      map = Maps.get_or_create_default_map()
      {:ok, map: map}
    end

    test "create_node/1 with valid data creates a node", %{map: map} do
      attrs = %{
        map_id: map.id,
        text: "Test Component",
        x_pct: 50.0,
        y_pct: 75.0,
        metadata: %{"type" => "service"}
      }

      assert {:ok, %Node{} = node} = Maps.create_node(attrs)
      assert node.text == "Test Component"
      assert node.x_pct == 50.0
      assert node.y_pct == 75.0
      assert node.metadata == %{"type" => "service"}
    end

    test "create_node/1 with invalid x_pct fails", %{map: map} do
      attrs = %{map_id: map.id, text: "Bad Node", x_pct: 150.0, y_pct: 50.0}

      assert {:error, changeset} = Maps.create_node(attrs)
      assert "must be less than or equal to 100.0" in errors_on(changeset).x_pct
    end

    test "create_node/1 with negative y_pct fails", %{map: map} do
      attrs = %{map_id: map.id, text: "Bad Node", x_pct: 50.0, y_pct: -10.0}

      assert {:error, changeset} = Maps.create_node(attrs)
      assert "must be greater than or equal to 0.0" in errors_on(changeset).y_pct
    end

    test "create_node/1 without text fails", %{map: map} do
      attrs = %{map_id: map.id, x_pct: 50.0, y_pct: 50.0}

      assert {:error, changeset} = Maps.create_node(attrs)
      assert "can't be blank" in errors_on(changeset).text
    end

    test "list_nodes/1 returns all nodes for a map", %{map: map} do
      {:ok, node1} = Maps.create_node(%{map_id: map.id, text: "Node 1", x_pct: 10.0, y_pct: 90.0})
      {:ok, node2} = Maps.create_node(%{map_id: map.id, text: "Node 2", x_pct: 80.0, y_pct: 20.0})

      nodes = Maps.list_nodes(map.id)

      assert length(nodes) == 2
      assert Enum.any?(nodes, &(&1.id == node1.id))
      assert Enum.any?(nodes, &(&1.id == node2.id))
    end

    test "get_node!/1 returns the node with given id", %{map: map} do
      {:ok, node} =
        Maps.create_node(%{map_id: map.id, text: "Findable", x_pct: 50.0, y_pct: 50.0})

      fetched = Maps.get_node!(node.id)

      assert fetched.id == node.id
      assert fetched.text == "Findable"
    end

    test "update_node/2 with valid data updates the node", %{map: map} do
      {:ok, node} =
        Maps.create_node(%{map_id: map.id, text: "Original", x_pct: 50.0, y_pct: 50.0})

      assert {:ok, updated} = Maps.update_node(node, %{text: "Updated", x_pct: 75.0})
      assert updated.text == "Updated"
      assert updated.x_pct == 75.0
      assert updated.y_pct == 50.0
    end

    test "update_node/2 with invalid data returns error changeset", %{map: map} do
      {:ok, node} =
        Maps.create_node(%{map_id: map.id, text: "Original", x_pct: 50.0, y_pct: 50.0})

      assert {:error, changeset} = Maps.update_node(node, %{x_pct: 200.0})
      assert "must be less than or equal to 100.0" in errors_on(changeset).x_pct
    end

    test "delete_node/1 deletes the node", %{map: map} do
      {:ok, node} =
        Maps.create_node(%{map_id: map.id, text: "Deletable", x_pct: 50.0, y_pct: 50.0})

      assert {:ok, %Node{}} = Maps.delete_node(node)
      assert_raise Ecto.NoResultsError, fn -> Maps.get_node!(node.id) end
    end

    test "node metadata defaults to empty map", %{map: map} do
      {:ok, node} =
        Maps.create_node(%{map_id: map.id, text: "No Metadata", x_pct: 50.0, y_pct: 50.0})

      assert node.metadata == %{}
    end
  end

  describe "edges" do
    setup do
      map = Maps.get_or_create_default_map()

      {:ok, source} =
        Maps.create_node(%{map_id: map.id, text: "Source", x_pct: 20.0, y_pct: 80.0})

      {:ok, target} =
        Maps.create_node(%{map_id: map.id, text: "Target", x_pct: 60.0, y_pct: 40.0})

      {:ok, map: map, source: source, target: target}
    end

    test "create_edge/1 with valid data creates an edge", %{
      map: map,
      source: source,
      target: target
    } do
      attrs = %{
        map_id: map.id,
        source_id: source.id,
        target_id: target.id,
        metadata: %{"relationship" => "requires"}
      }

      assert {:ok, %Edge{} = edge} = Maps.create_edge(attrs)
      assert edge.source_id == source.id
      assert edge.target_id == target.id
      assert edge.metadata == %{"relationship" => "requires"}
    end

    test "create_edge/1 without source_id fails", %{map: map, target: target} do
      attrs = %{map_id: map.id, target_id: target.id}

      assert {:error, changeset} = Maps.create_edge(attrs)
      assert "can't be blank" in errors_on(changeset).source_id
    end

    test "list_edges/1 returns all edges for a map", %{map: map, source: source, target: target} do
      {:ok, edge} =
        Maps.create_edge(%{map_id: map.id, source_id: source.id, target_id: target.id})

      edges = Maps.list_edges(map.id)

      assert length(edges) == 1
      assert hd(edges).id == edge.id
    end

    test "get_edge!/1 returns the edge with given id", %{map: map, source: source, target: target} do
      {:ok, edge} =
        Maps.create_edge(%{map_id: map.id, source_id: source.id, target_id: target.id})

      fetched = Maps.get_edge!(edge.id)

      assert fetched.id == edge.id
    end

    test "update_edge/2 updates edge metadata", %{map: map, source: source, target: target} do
      {:ok, edge} =
        Maps.create_edge(%{map_id: map.id, source_id: source.id, target_id: target.id})

      assert {:ok, updated} = Maps.update_edge(edge, %{metadata: %{"relationship" => "uses"}})
      assert updated.metadata == %{"relationship" => "uses"}
    end

    test "delete_edge/1 deletes the edge", %{map: map, source: source, target: target} do
      {:ok, edge} =
        Maps.create_edge(%{map_id: map.id, source_id: source.id, target_id: target.id})

      assert {:ok, %Edge{}} = Maps.delete_edge(edge)
      assert_raise Ecto.NoResultsError, fn -> Maps.get_edge!(edge.id) end
    end

    test "edge metadata defaults to empty map", %{map: map, source: source, target: target} do
      {:ok, edge} =
        Maps.create_edge(%{map_id: map.id, source_id: source.id, target_id: target.id})

      assert edge.metadata == %{}
    end
  end

  describe "map ownership" do
    setup do
      user = Wardley.AccountsFixtures.user_fixture()
      other_user = Wardley.AccountsFixtures.user_fixture(%{email: "other@example.com"})
      {:ok, owned_map} = Maps.create_map(%{name: "My Map", user_id: user.id})
      {:ok, other_map} = Maps.create_map(%{name: "Other Map", user_id: other_user.id})
      {:ok, user: user, other_user: other_user, owned_map: owned_map, other_map: other_map}
    end

    test "list_maps_for_user returns only owned maps", %{user: user, owned_map: owned_map} do
      maps = Maps.list_maps_for_user(user.id)
      map_ids = Enum.map(maps, & &1.id)

      assert owned_map.id in map_ids
    end

    test "list_maps_for_user includes maps where user is a member", %{
      user: user,
      other_map: other_map
    } do
      {:ok, _} = Maps.add_member(other_map.id, user.id)
      maps = Maps.list_maps_for_user(user.id)
      map_ids = Enum.map(maps, & &1.id)

      assert other_map.id in map_ids
    end

    test "can_access_map? returns true for owner", %{user: user, owned_map: owned_map} do
      assert Maps.can_access_map?(owned_map.id, user.id)
    end

    test "can_access_map? returns false for non-member", %{user: user, other_map: other_map} do
      refute Maps.can_access_map?(other_map.id, user.id)
    end

    test "can_access_map? returns true for member", %{user: user, other_map: other_map} do
      {:ok, _} = Maps.add_member(other_map.id, user.id)
      assert Maps.can_access_map?(other_map.id, user.id)
    end

    test "owns_map? returns true for owner", %{user: user, owned_map: owned_map} do
      assert Maps.owns_map?(owned_map.id, user.id)
    end

    test "owns_map? returns false for member", %{user: user, other_map: other_map} do
      {:ok, _} = Maps.add_member(other_map.id, user.id)
      refute Maps.owns_map?(other_map.id, user.id)
    end
  end

  describe "map visibility" do
    setup do
      owner = Wardley.AccountsFixtures.user_fixture(%{email: "vis-owner@example.com"})
      other = Wardley.AccountsFixtures.user_fixture(%{email: "vis-other@example.com"})
      {:ok, public_map} = Maps.create_map(%{name: "Public", user_id: owner.id})

      {:ok, private_map} =
        Maps.create_map(%{name: "Private", user_id: owner.id, visibility: "private"})

      {:ok, owner: owner, other: other, public_map: public_map, private_map: private_map}
    end

    test "maps default to public", %{public_map: public_map} do
      assert public_map.visibility == "public"
    end

    test "list_maps includes public maps for an anonymous caller", %{public_map: public_map} do
      ids = Maps.list_maps(nil) |> Enum.map(& &1.id)
      assert public_map.id in ids
    end

    test "list_maps hides private maps from an anonymous caller", %{private_map: private_map} do
      ids = Maps.list_maps(nil) |> Enum.map(& &1.id)
      refute private_map.id in ids
    end

    test "list_maps hides private maps from a non-member", %{
      other: other,
      private_map: private_map
    } do
      ids = Maps.list_maps(other.id) |> Enum.map(& &1.id)
      refute private_map.id in ids
    end

    test "list_maps shows a private map to its owner", %{owner: owner, private_map: private_map} do
      ids = Maps.list_maps(owner.id) |> Enum.map(& &1.id)
      assert private_map.id in ids
    end

    test "list_maps shows a private map to a member", %{
      other: other,
      private_map: private_map
    } do
      {:ok, _} = Maps.add_member(private_map.id, other.id)
      ids = Maps.list_maps(other.id) |> Enum.map(& &1.id)
      assert private_map.id in ids
    end

    test "can_view_map? allows anyone to view a public map", %{
      other: other,
      public_map: public_map
    } do
      assert Maps.can_view_map?(public_map.id, nil)
      assert Maps.can_view_map?(public_map.id, other.id)
    end

    test "can_view_map? denies a non-member viewing a private map", %{
      other: other,
      private_map: private_map
    } do
      refute Maps.can_view_map?(private_map.id, nil)
      refute Maps.can_view_map?(private_map.id, other.id)
    end

    test "can_view_map? allows owner and member to view a private map", %{
      owner: owner,
      other: other,
      private_map: private_map
    } do
      assert Maps.can_view_map?(private_map.id, owner.id)
      {:ok, _} = Maps.add_member(private_map.id, other.id)
      assert Maps.can_view_map?(private_map.id, other.id)
    end

    test "rejects an invalid visibility value", %{owner: owner} do
      assert {:error, changeset} =
               Maps.create_map(%{name: "Bad", user_id: owner.id, visibility: "secret"})

      assert %{visibility: _} = errors_on(changeset)
    end
  end

  describe "memberships" do
    setup do
      user = Wardley.AccountsFixtures.user_fixture(%{email: "owner-m@example.com"})
      member = Wardley.AccountsFixtures.user_fixture(%{email: "member-m@example.com"})
      {:ok, map} = Maps.create_map(%{name: "Team Map", user_id: user.id})
      {:ok, owner: user, member: member, map: map}
    end

    test "add_member creates a membership", %{map: map, member: member} do
      assert {:ok, membership} = Maps.add_member(map.id, member.id)
      assert membership.role == "editor"
    end

    test "add_member rejects duplicate", %{map: map, member: member} do
      {:ok, _} = Maps.add_member(map.id, member.id)
      assert {:error, _changeset} = Maps.add_member(map.id, member.id)
    end

    test "list_memberships returns members with users", %{map: map, member: member} do
      {:ok, _} = Maps.add_member(map.id, member.id)
      memberships = Maps.list_memberships(map.id)

      assert length(memberships) == 1
      assert hd(memberships).user.email == member.email
    end

    test "remove_member deletes the membership", %{map: map, member: member} do
      {:ok, _} = Maps.add_member(map.id, member.id)
      assert {:ok, _} = Maps.remove_member(map.id, member.id)
      assert Maps.list_memberships(map.id) == []
    end

    test "remove_member returns error for non-member", %{map: map, member: member} do
      assert {:error, :not_found} = Maps.remove_member(map.id, member.id)
    end
  end
end
