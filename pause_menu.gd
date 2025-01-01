extends Control

var music_player: AudioStreamPlayer = null
@onready var hslider = $MarginContainer/VBoxContainer/HSlider
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	music_player = get_node("/root/Main/MusicPlayer")
	music_player.volume_db = -40.0
	hslider.value = 0
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_h_slider_value_changed(value: float) -> void:
	music_player.volume_db = value - 80
