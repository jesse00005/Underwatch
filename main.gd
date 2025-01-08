extends Node

@onready var host_button = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/HostButton
@onready var join_button = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/JoinButton
@onready var start_game_button = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/StartGameButton

@onready var error_label = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/ErrorLabel
@onready var players_label = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/PlayersLabel

@onready var map_dropdown = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/HBoxContainer/MapSelect
@onready var character_dropdown = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/HBoxContainer2/CharacterSelect

@onready var title_screen_music_player = $TitleScreenMusicPlayer

var selected_map_id = null

func _ready():
	# Preconfigure game.
	Lobby.player_loaded.rpc_id(1) # Tell the server that this peer has loaded.
	
	host_button.pressed.connect(host_game)
	join_button.pressed.connect(join_game)
	start_game_button.pressed.connect(start_game)
	Lobby.player_connected.connect(update_lobby_info)
	Lobby.player_disconnected.connect(update_lobby_info)

func update_lobby_info(new_player_id, new_player_info):
	var res = ""
	for peer_id in Lobby.players.keys():
		var player_info = Lobby.players[peer_id]
		res += str(peer_id) + ": " + str(player_info["selected_character_id"]) + "\n"
	players_label.text = res

func host_game():
	if selected_map_id == null || Lobby.player_info["selected_character_id"] == null:
		error_label.text = "Select a map and character before hosting"
		return
	start_game_button.visible = true
	host_button.visible = false
	Lobby.create_game()

func join_game():
	if Lobby.player_info["selected_character_id"] == null:
		error_label.text = "Select a character before joining"
		return
	Lobby.join_game("localhost")

func start_game():
	Lobby.load_game.rpc(selected_map_id)
	print("Starting game!")

func _on_option_button_item_selected(index: int) -> void:
	selected_map_id = index + 1


func _on_character_select_item_selected(index: int) -> void:
	Lobby.player_info["selected_character_id"] = index + 1


func _on_title_screen_music_volume_slider_value_changed(value: float) -> void:
	if value < 0.01:
		$TitleScreenMusicPlayer.attenuation = 1000000
	$TitleScreenMusicPlayer.attenuation = 1
	$TitleScreenMusicPlayer.volume_db = linear_to_db(value)
