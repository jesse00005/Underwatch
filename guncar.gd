extends "res://player.gd"

@onready var anim = $Pivot/guncar2/AnimationPlayer


func configure_hero():
	max_health = 500
	speed = 2.5
	weapon_damage = 100
	shoot_cooldown = 0.5


func _input(event):
	process_look_input(event)

	if not is_multiplayer_authority() or isPaused:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if anim.current_animation == "shoot":
			return
		if not can_fire_weapon():
			return

		play_shoot_effects.rpc()
		perform_hitscan_attack(weapon_damage)


@rpc("call_local")
func play_shoot_effects():
	$PeterGun.playing = true
	anim.play("shoot")
