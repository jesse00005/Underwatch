extends "res://player.gd"

const BLASTER_RANGE = 55.0
const BLASTER_DAMAGE = 26
const MELEE_DAMAGE = 70
const MELEE_RANGE = 2.3
const MELEE_COOLDOWN = 0.65
const FUSION_GRENADE_SCENE = preload("res://fusion_grenade.tscn")
const FUSION_GRENADE_DAMAGE = 75
const FUSION_GRENADE_RADIUS = 3.8
const FUSION_GRENADE_COOLDOWN = 8.0
const FUSION_GRENADE_SPEED = 19.0
const FUSION_GRENADE_UPWARD_BOOST = 3.6
const FUSION_GRENADE_GRAVITY = 18.0
const GRENADE_ARC_STEPS = 18
const GRENADE_ARC_STEP_TIME = 0.08

@onready var blaster_audio = $BlasterShot
@onready var grenade_throw_audio = $GrenadeThrowSound
@onready var grenade_arc = $GrenadeArc
@onready var muzzle_flash = $Pivot/ModelRoot/MuzzleFlash
@onready var wrench_pivot = $Pivot/ModelRoot/WrenchPivot

var muzzle_flash_timer = 0.0
var wrench_swing_timer = 0.0
var wrench_rest_rotation = Vector3.ZERO
var combat_strafe_active = false
var grenade_preview_active = false
var default_camera_position = Vector3.ZERO
var default_camera_fov = 0.0


func _ready():
	super()
	wrench_rest_rotation = wrench_pivot.rotation
	default_camera_position = camera.position
	default_camera_fov = camera.fov
	muzzle_flash.visible = false


func configure_hero():
	max_health = 250
	speed = 3.2
	strafe_speed_multiplier = 1.45
	ground_acceleration = 28.0
	air_acceleration = 14.0
	jump_impulse = 5.3
	allow_double_jump = true
	double_jump_impulse = 4.6
	dash_speed = 11.5
	dash_duration = 0.18
	dash_cooldown = 6.0
	shoot_cooldown = 0.14
	weapon_damage = BLASTER_DAMAGE


func _input(event):
	process_look_input(event)


func _process(delta):
	if not is_multiplayer_authority():
		return

	combat_strafe_active = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	grenade_preview_active = Input.is_action_pressed("ability_2")
	_update_visual_timers(delta)
	_update_combat_strafe_camera(delta)
	_update_grenade_arc()

	if isPaused:
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_fire_blaster()

	if Input.is_action_just_pressed("melee"):
		_try_wrench_swing()

	if Input.is_action_just_pressed("ability_1"):
		try_activate_dash()

	if Input.is_action_just_released("ability_2"):
		_try_throw_fusion_grenade()


func _try_fire_blaster():
	if not can_fire_weapon():
		return

	play_shoot_effects.rpc()
	perform_hitscan_attack(BLASTER_DAMAGE, BLASTER_RANGE)


func _try_wrench_swing():
	if not is_ability_ready("melee"):
		return

	start_ability_cooldown("melee", MELEE_COOLDOWN)
	wrench_swing_timer = 0.14
	perform_melee_attack(MELEE_DAMAGE, MELEE_RANGE, 85.0)


func _try_throw_fusion_grenade():
	if not is_ability_ready("fusion_grenade"):
		return

	start_ability_cooldown("fusion_grenade", FUSION_GRENADE_COOLDOWN)

	var throw_state = _get_grenade_throw_state()
	var throw_direction = throw_state.direction
	var spawn_position = throw_state.spawn_position
	play_grenade_throw_effects.rpc()
	spawn_fusion_grenade.rpc(spawn_position, throw_direction, get_multiplayer_authority())


@rpc("call_local")
func spawn_fusion_grenade(spawn_position, throw_direction, owner_peer_id):
	var grenade = FUSION_GRENADE_SCENE.instantiate()
	get_tree().current_scene.add_child(grenade)
	grenade.setup(
		spawn_position,
		throw_direction,
		owner_peer_id,
		FUSION_GRENADE_SPEED,
		FUSION_GRENADE_UPWARD_BOOST,
		FUSION_GRENADE_RADIUS,
		FUSION_GRENADE_DAMAGE
	)


func _update_grenade_arc():
	if grenade_arc == null:
		return

	grenade_arc.visible = grenade_preview_active and is_ability_ready("fusion_grenade") and not isPaused
	if not grenade_arc.visible:
		var hidden_mesh = grenade_arc.mesh
		if hidden_mesh != null:
			hidden_mesh.clear_surfaces()
		return

	var throw_state = _get_grenade_throw_state()
	var simulated_position = throw_state.spawn_position
	var simulated_velocity = throw_state.velocity

	var arc_mesh = grenade_arc.mesh
	if arc_mesh == null:
		return

	arc_mesh.clear_surfaces()
	arc_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for _step in range(GRENADE_ARC_STEPS):
		arc_mesh.surface_add_vertex(to_local(simulated_position))
		var next_velocity = simulated_velocity
		next_velocity.y -= FUSION_GRENADE_GRAVITY * GRENADE_ARC_STEP_TIME
		var next_position = simulated_position + next_velocity * GRENADE_ARC_STEP_TIME
		var hit = _raycast_grenade_arc(simulated_position, next_position)
		if not hit.is_empty():
			arc_mesh.surface_add_vertex(to_local(hit.position))
			break
		simulated_velocity = next_velocity
		simulated_position = next_position
	arc_mesh.surface_end()


func _get_grenade_throw_state():
	var throw_direction = (-camera.global_transform.basis.z).normalized()
	var spawn_position = global_position + Vector3.UP * 0.9 + throw_direction * 0.7
	var velocity = throw_direction * FUSION_GRENADE_SPEED
	velocity.y += FUSION_GRENADE_UPWARD_BOOST
	return {
		"direction": throw_direction,
		"spawn_position": spawn_position,
		"velocity": velocity,
	}


func _raycast_grenade_arc(from_position, to_position):
	var query = PhysicsRayQueryParameters3D.create(from_position, to_position)
	query.collide_with_areas = false
	query.collision_mask = 3
	query.exclude = [self]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _get_desired_world_velocity():
	var input_vector = Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")
	var active_strafe_multiplier = strafe_speed_multiplier
	var forward_multiplier = 1.0

	if combat_strafe_active:
		active_strafe_multiplier = 1.9
		forward_multiplier = 1.08

	var local_velocity = Vector3(
		input_vector.x * speed * active_strafe_multiplier,
		0,
		input_vector.y * speed * forward_multiplier
	)

	var max_speed = speed * max(active_strafe_multiplier, forward_multiplier)
	if local_velocity.length() > max_speed:
		local_velocity = local_velocity.normalized() * max_speed

	isMoving = local_velocity.length_squared() > 0.01
	return local_velocity.rotated(Vector3.UP, rotation.y)


func _update_visual_timers(delta):
	muzzle_flash_timer = max(muzzle_flash_timer - delta, 0.0)
	muzzle_flash.visible = muzzle_flash_timer > 0.0

	if wrench_swing_timer > 0.0:
		wrench_swing_timer = max(wrench_swing_timer - delta, 0.0)
		var swing_strength = wrench_swing_timer / 0.14
		wrench_pivot.rotation_degrees.z = lerp(-135.0, -35.0, swing_strength)
	else:
		wrench_pivot.rotation = wrench_pivot.rotation.lerp(wrench_rest_rotation, min(delta * 16.0, 1.0))


func _update_combat_strafe_camera(delta):
	var target_position = default_camera_position
	var target_fov = default_camera_fov

	if combat_strafe_active:
		target_position = default_camera_position + Vector3(0.12, 0.02, 0.14)
		target_fov = default_camera_fov - 8.0

	camera.position = camera.position.lerp(target_position, min(delta * 10.0, 1.0))
	camera.fov = lerp(camera.fov, target_fov, min(delta * 10.0, 1.0))


@rpc("call_local")
func play_shoot_effects():
	blaster_audio.play()
	muzzle_flash_timer = 0.05


@rpc("call_local")
func play_grenade_throw_effects():
	grenade_throw_audio.play()
