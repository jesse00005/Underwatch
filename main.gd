extends Node

@onready var host_button = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/HostButton
@onready var join_button = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/JoinButton
@onready var start_game_button = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/StartGameButton

@onready var error_label = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/ErrorLabel
@onready var players_label = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/PlayersLabel
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry

@onready var map_dropdown = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/HBoxContainer/MapSelect
@onready var character_dropdown = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/HBoxContainer2/CharacterSelect

var selected_map_id = null


func _ready():
	_populate_menu_options()
	Lobby.player_connected.connect(update_lobby_info)
	Lobby.player_disconnected.connect(update_lobby_info)


func _populate_menu_options():
	map_dropdown.clear()
	var map_ids = Constants.mapsById.keys()
	map_ids.sort()
	for map_id in map_ids:
		map_dropdown.add_item(Constants.mapsById[map_id]["name"], map_id)
	if map_ids.size() > 0:
		map_dropdown.select(0)
		selected_map_id = map_dropdown.get_item_id(0)

	character_dropdown.clear()
	var character_ids = Constants.charactersById.keys()
	character_ids.sort()
	for character_id in character_ids:
		character_dropdown.add_item(Constants.charactersById[character_id]["name"], character_id)
	if character_ids.size() > 0:
		character_dropdown.select(0)
		Lobby.player_info["selected_character_id"] = character_dropdown.get_item_id(0)
	update_lobby_info()


func update_lobby_info(_peer_id = 0, _player_info = null):
	var rows = []
	var peer_ids = Lobby.players.keys()
	peer_ids.sort()
	for peer_id in peer_ids:
		var player_info = Lobby.players[peer_id]
		var character_id = player_info.get("selected_character_id", null)
		var character_name = "Unselected"
		if character_id != null and Constants.charactersById.has(character_id):
			character_name = Constants.charactersById[character_id]["name"]
		rows.append("%s: %s" % [peer_id, character_name])
	players_label.text = "\n".join(rows)


func host_game():
	if selected_map_id == null or Lobby.player_info["selected_character_id"] == null:
		error_label.text = "Select a map and character before hosting"
		return

	error_label.text = ""
	start_game_button.visible = true
	host_button.visible = false
	Lobby.create_game()


func join_game():
	if Lobby.player_info["selected_character_id"] == null:
		error_label.text = "Select a character before joining"
		return

	error_label.text = ""
	var address = address_entry.text.strip_edges()
	Lobby.join_game(address)


func start_game():
	if selected_map_id == null:
		error_label.text = "Select a map before starting"
		return

	Lobby.load_game.rpc(selected_map_id)
	print("Starting game!")


func _on_option_button_item_selected(index):
	selected_map_id = map_dropdown.get_item_id(index)


func _on_character_select_item_selected(index):
	Lobby.player_info["selected_character_id"] = character_dropdown.get_item_id(index)
	update_lobby_info()


func _on_title_screen_music_volume_slider_value_changed(value):
	if value < 0.01:
		$TitleScreenMusicPlayer.volume_db = -80.0
		return
	$TitleScreenMusicPlayer.volume_db = linear_to_db(value)
