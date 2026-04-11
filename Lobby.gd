extends Node

# Autoload named Lobby

# These signals can be connected to by a UI lobby scene or the game scene.
signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1" # IPv4 localhost
const MAX_CONNECTIONS = 20
const FALLBACK_SPAWN_POINTS = [
	Vector3(0, 0, 0),
	Vector3(3, 0, 0),
	Vector3(-3, 0, 0),
	Vector3(0, 0, 3),
	Vector3(0, 0, -3),
]

# This will contain player info for every player,
# with the keys being each player's unique IDs.
var players = {}

var player_nodes = {}
var spawn_points_by_peer = {}
var active_hud = null

# This is the local player info. This should be modified locally
# before the connection is made. It will be passed to every other peer.
# For example, the value of "name" can be set to something the player
# entered in a UI scene.
var player_info = {
	"name": "Name",
	"selected_character_id": null,
}


func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func join_game(address = ""):
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error:
		return error
	multiplayer.multiplayer_peer = peer


func create_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error:
		return error
	multiplayer.multiplayer_peer = peer

	players[1] = player_info
	player_connected.emit(1, player_info)


func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null


@rpc("call_local", "reliable")
func load_game(map_id):
	var map = Constants.mapsById.get(map_id)
	if map == null:
		push_error("Unknown map id: %s" % map_id)
		return

	get_tree().change_scene_to_packed(map.scene)

	_free_existing_players()
	_free_existing_hud()

	var peer_ids = players.keys()
	peer_ids.sort()

	var local_player = null
	for index in range(peer_ids.size()):
		var peer_id = peer_ids[index]
		var selected_character_id = players[peer_id].get("selected_character_id", 1)
		var character = Constants.charactersById.get(selected_character_id, Constants.charactersById[1])
		var player = character.scene.instantiate()
		player.name = str(peer_id)
		add_child(player)
		player.global_position = _resolve_spawn_position(index)

		player_nodes[peer_id] = player
		spawn_points_by_peer[peer_id] = player.global_position

		if player.is_multiplayer_authority():
			local_player = player

	if local_player != null:
		_create_hud_for_player(local_player)


@rpc("any_peer", "call_local", "reliable")
func player_loaded():
	pass


func _free_existing_hud():
	if active_hud != null and is_instance_valid(active_hud):
		active_hud.queue_free()
	active_hud = null


func _free_existing_players():
	for peer_id in player_nodes.keys():
		var player = player_nodes[peer_id]
		if player != null and is_instance_valid(player):
			player.queue_free()
	player_nodes.clear()
	spawn_points_by_peer.clear()


func _create_hud_for_player(player):
	active_hud = preload("res://hud.tscn").instantiate()
	add_child(active_hud)
	active_hud.visible = true

	var health_bar = active_hud.get_node("HealthBar")
	health_bar.max_value = player.max_health
	health_bar.value = player.health
	player.health_changed.connect(_on_player_health_changed.bind(player, health_bar))


func _on_player_health_changed(health_value, player, health_bar):
	if health_bar == null or not is_instance_valid(health_bar):
		return
	if player == null or not is_instance_valid(player):
		return
	health_bar.max_value = player.max_health
	health_bar.value = health_value


func _resolve_spawn_position(index):
	var scene_spawn_points = _find_scene_spawn_points()
	if scene_spawn_points.size() > 0:
		return scene_spawn_points[index % scene_spawn_points.size()]

	return FALLBACK_SPAWN_POINTS[index % FALLBACK_SPAWN_POINTS.size()]


func _find_scene_spawn_points():
	var spawn_points = []
	var current_scene = get_tree().current_scene
	if current_scene == null:
		return spawn_points

	for node in get_tree().get_nodes_in_group("player_spawn"):
		if node is Node3D and current_scene.is_ancestor_of(node):
			spawn_points.append(node.global_position)

	return spawn_points


func get_spawn_position_for_peer(peer_id):
	return spawn_points_by_peer.get(peer_id, FALLBACK_SPAWN_POINTS[0])


# When a peer connects, send them my player info.
# This allows transfer of all desired data for each player, not only the unique ID.
func _on_player_connected(id):
	_register_player.rpc_id(id, player_info)


func get_node_from_peer_id(peer_id):
	return player_nodes.get(peer_id, null)


@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)
	print("Players: ", players)


func _on_player_disconnected(id):
	players.erase(id)
	player_disconnected.emit(id)
	player_nodes.erase(id)
	spawn_points_by_peer.erase(id)


func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)


func _on_connected_fail():
	multiplayer.multiplayer_peer = null


func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	_free_existing_players()
	_free_existing_hud()
	server_disconnected.emit()
