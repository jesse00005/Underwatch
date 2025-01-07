extends Player

@onready var muzzle_flash = $Pivot/peterrigged4/MuzzleFlash
@onready var anim = $Pivot/peterrigged4/AnimationPlayer

func _input(event):
	
	if not is_multiplayer_authority():
		return
				
	if !isPaused:
		if event is InputEventMouseMotion:
			yaw -= event.relative.x * mouse_sensitivity
			pitch -= event.relative.y * mouse_sensitivity
			pitch = clamp (pitch, -45.0, 90.0)
				
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if anim.current_animation != "shoot_run" and anim.current_animation != "shoot_still":
					
					play_shoot_effects.rpc()
					if raycast.is_colliding():
						var hit_player = raycast.get_collider()
						#hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())
						rpc("deal_damage", hit_player.get_multiplayer_authority(), weapon_damage)

func _process(delta):
	if isMoving:
		if anim.current_animation != "shoot_run" and anim.current_animation != "shoot_still":
			anim.play("Object_4Action")	
	if !isMoving:
		anim.stop
		if anim.current_animation != "shoot_still" and anim.current_animation != "shoot_run":
			anim.play("mixamo_com_Object_4")

func play_shoot_effects():
	$PeterGun.playing = true
	if isMoving:
			anim.play("shoot_run")
	elif !isMoving:
		anim.play("shoot_still")
	muzzle_flash.restart()
