extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var hud = $CanvasLayer/HUD
@onready var health_bar = $CanvasLayer/HUD/HealthBar
@onready var pause_menu = $CanvasLayer/PauseMenu
@onready var map_dropdown = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/HBoxContainer/MapSelect
@onready var selected_map_index = null
@onready var error_label = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/ErrorLabel
@onready var selected_character
@onready var selected_character_index = null
@onready var character_dropdown = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/HBoxContainer2/CharacterSelect

const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()
const Peter = preload("res://player.tscn")
const Streets = preload("res://skreets.tscn")
const Dalaran = preload("res://dalaran.tscn")
const Gun_Car = preload("res://guncar.tscn")

const characters = [
	Peter,
	Gun_Car,
]
const maps = [
	Streets,
	Dalaran
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass






func _on_host_button_pressed() -> void:
	if map_dropdown.get_selected_id() > -1 and character_dropdown.get_selected_id() > -1:
		var map = maps[selected_map_index].instantiate()
		add_child(map)
		main_menu.hide()
		hud.show()
		enet_peer.create_server(PORT)
		multiplayer.multiplayer_peer = enet_peer
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(remove_player)
		
		add_player(multiplayer.get_unique_id(), selected_character_index)
		print("Hosting server on PORT:", PORT)
		$MusicPlayer.playing = true
	else:
		error_label.text = "Select a map and character before hosting"
		
	
	

func _on_join_button_pressed() -> void:
	if character_dropdown.get_selected_id() > -1:
		var host_ip = address_entry.text.strip_edges() 
		if host_ip == "":
			error_label.text = "Please enter a valid Hamachi IP address."
			return
		main_menu.hide()
		hud.show()
		#enet_peer.create_client(host_ip, PORT)    ############
		enet_peer.create_client("localhost", PORT) ############ change for testing/exporting
		multiplayer.multiplayer_peer = enet_peer
		print("Attempting to join server at IP:", host_ip, "PORT:", PORT)
		$MusicPlayer.playing = true
	else:
		error_label.text = "Select a character before joining"

func add_player(peer_id, selected_character_index):
	var player = characters[selected_character_index].instantiate()
	player.name = str(peer_id)
	add_child(player)
	if player.is_multiplayer_authority():
		player.health_changed.connect(update_health_bar)

func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func _on_peer_connected(peer_id: int):
	print("Peer connected with ID: ", peer_id)
	if selected_map_index != null:
		print("sending map to peer: ", peer_id)
		rpc_id(peer_id, "load_map", selected_map_index)
		add_player(peer_id, selected_character_index)
	else:
		print("No map selected; cannot send map to peer.")

@rpc("call_remote")
func load_map(selected_map_index: int):
	var map = maps[selected_map_index].instantiate()
	add_child(map)
	print("Loaded map")

func update_health_bar(health_value):
	health_bar.value = health_value

func _on_multiplayer_spawner_spawned(node: Node) -> void:
	if node.is_multiplayer_authority():
		node.health_changed.connect(update_health_bar)
		


func _on_option_button_item_selected(index: int) -> void:
	selected_map_index = index


func _on_character_select_item_selected(index: int) -> void:
	selected_character_index = index
	if index == 0:
		selected_character = Peter
	if index == 1:
		selected_character = Gun_Car
