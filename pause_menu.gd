extends Control

@onready var music_player = $"../MusicPlayer"
@onready var hslider = $MarginContainer/VBoxContainer/HSlider
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_music_slider_value_changed(value: float) -> void:
	if value < 0.01:
		music_player.attenuation = 1000000
	music_player.attenuation = 1
	music_player.volume_db = linear_to_db(value)
