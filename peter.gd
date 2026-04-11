extends "res://player.gd"

@onready var muzzle_flash = $Pivot/peterrigged4/MuzzleFlash
@onready var anim = $Pivot/peterrigged4/AnimationPlayer


func configure_hero():
	max_health = 300
	speed = 2.5
	weapon_damage = 60
	shoot_cooldown = 0.5


func _input(event):
	process_look_input(event)

	if not is_multiplayer_authority() or isPaused:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if anim.current_animation == "shoot_run" or anim.current_animation == "shoot_still":
			return
		if not can_fire_weapon():
			return

		play_shoot_effects.rpc()
		perform_hitscan_attack(weapon_damage)


func _process(_delta):
	if isMoving:
		if anim.current_animation != "shoot_run" and anim.current_animation != "shoot_still":
			anim.play("Object_4Action")
	else:
		anim.stop()
		if anim.current_animation != "shoot_still" and anim.current_animation != "shoot_run":
			anim.play("mixamo_com_Object_4")


func on_eliminated():
	$peter_laugh.playing = true


@rpc("call_local")
func play_shoot_effects():
	$PeterGun.playing = true
	if isMoving:
		anim.play("shoot_run")
	else:
		anim.play("shoot_still")
	muzzle_flash.restart()
