extends Player

@onready var anim = $Pivot/guncar2/AnimationPlayer


func _input(event):
	
	if not is_multiplayer_authority():
		return
	if !isPaused:
		if event is InputEventMouseMotion:
			yaw -= event.relative.x * mouse_sensitivity
			pitch -= event.relative.y * mouse_sensitivity
			pitch = clamp (pitch, -45.0, 90.0)
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and anim.current_animation != "shoot":
		#shoot_projectile()
			
			play_shoot_effects.rpc()
			if raycast.is_colliding():
				var hit_player = raycast.get_collider()
				rpc("deal_damage", hit_player.get_multiplayer_authority(), weapon_damage)
			

@rpc("call_local")
func play_shoot_effects():
	$PeterGun.playing = true
	anim.play("shoot")
