extends Node

@onready var host_button = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/HostButton
@onready var join_button = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/JoinButton
@onready var error_label = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/ErrorLabel
@onready var players_label = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/PlayersLabel

@onready var map_dropdown = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/HBoxContainer/MapSelect
@onready var character_dropdown = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/HBoxContainer2/CharacterSelect

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

func _ready():
	# Preconfigure game.
	Lobby.player_loaded.rpc_id(1) # Tell the server that this peer has loaded.
	
	host_button.pressed.connect(start_game)
	join_button.pressed.connect(join_game)
	Lobby.player_connected.connect(on_player_connected)

func on_player_connected(new_player_id, new_player_info):
	var res = ""
	for peer_id in Lobby.players.keys():
		res += str(peer_id) + "\n"
	players_label.text = res

func join_game():
	if !Lobby.player_info["selected_character_id"]:
		error_label.text = "Select a character before joining"
		return
	Lobby.join_game("localhost")

func start_game():
	Lobby.create_game()
	print("Created game")

func _on_option_button_item_selected(index: int) -> void:
	return


func _on_character_select_item_selected(index: int) -> void:
	Lobby.player_info["selected_character_id"] = index
