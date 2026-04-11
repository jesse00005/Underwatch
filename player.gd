extends CharacterBody3D

signal health_changed(health_value)

@export var speed = 2.5
@export var strafe_speed_multiplier = 1.0
@export var ground_acceleration = 24.0
@export var air_acceleration = 10.0
@export var fall_acceleration = 30.0
@export var jump_impulse = 5.0
@export var allow_double_jump = false
@export var double_jump_impulse = 4.0
@export var dash_speed = 0.0
@export var dash_duration = 0.0
@export var dash_cooldown = 0.0

@export var projectile_scene = preload("res://projectile.tscn")
@export var shoot_offset = Vector3(0.1, 0.3, 0)
@export var weapon_damage = 60
@export var max_health = 300
@export var health = 300
@export var mouse_sensitivity = 0.2

@onready var pause_menu = $PauseMenu
@onready var raycast = $Camera3D/RayCast3D
@onready var camera = $Camera3D

var isMoving = false
var isPaused = false
var yaw = 0.0
var pitch = 0.0

var horizontal_velocity = Vector3.ZERO
var vertical_velocity = 0.0
var jump_count = 0
var dash_timer = 0.0
var dash_direction = Vector3.ZERO

var last_shot_time = 0.0
var shoot_cooldown = 0.5
var ability_cooldowns = {}


func _enter_tree():
	set_multiplayer_authority(str(name).to_int())


func _ready():
	configure_hero()
	health = max_health

	if not is_multiplayer_authority():
		return

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.current = true
	last_shot_time = -shoot_cooldown


func configure_hero():
	pass


func process_look_input(event):
	if not is_multiplayer_authority() or isPaused:
		return

	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -45.0, 90.0)


func can_fire_weapon():
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_shot_time < shoot_cooldown:
		return false
	last_shot_time = current_time
	return true


func is_ability_ready(ability_name):
	return ability_cooldowns.get(ability_name, 0.0) <= 0.0


func start_ability_cooldown(ability_name, duration):
	if duration <= 0.0:
		return
	ability_cooldowns[ability_name] = duration


func get_ability_cooldown_remaining(ability_name):
	return max(ability_cooldowns.get(ability_name, 0.0), 0.0)


func _is_damageable_player(candidate):
	return candidate != null and candidate != self and candidate.has_method("receive_damage") and candidate.has_method("get_multiplayer_authority")


func perform_hitscan_attack(damage, range_override = 50.0):
	var previous_target = raycast.target_position
	raycast.target_position = Vector3(0, 0, -range_override)
	raycast.force_raycast_update()

	var hit_player = null
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if _is_damageable_player(collider):
			hit_player = collider

	raycast.target_position = previous_target
	if hit_player == null:
		return false

	rpc("deal_damage", hit_player.get_multiplayer_authority(), damage)
	return true


func perform_melee_attack(damage, attack_range = 2.2, attack_angle_deg = 70.0):
	var forward = -camera.global_transform.basis.z
	forward.y = 0
	if forward.length_squared() == 0.0:
		return false
	forward = forward.normalized()

	var best_target = null
	var best_distance = INF
	var minimum_dot = cos(deg_to_rad(attack_angle_deg))

	for peer_id in Lobby.player_nodes.keys():
		var candidate = Lobby.player_nodes[peer_id]
		if candidate == null or candidate == self:
			continue
		if not _is_damageable_player(candidate):
			continue

		var to_target = candidate.global_position - global_position
		to_target.y = 0
		var distance = to_target.length()
		if distance == 0.0 or distance > attack_range:
			continue

		var facing_dot = forward.dot(to_target.normalized())
		if facing_dot < minimum_dot:
			continue

		if distance < best_distance:
			best_distance = distance
			best_target = candidate

	if best_target == null:
		return false

	rpc("deal_damage", best_target.get_multiplayer_authority(), damage)
	return true


func deal_radial_damage(origin, radius, damage):
	for peer_id in Lobby.player_nodes.keys():
		var candidate = Lobby.player_nodes[peer_id]
		if candidate == null or candidate == self:
			continue
		if not _is_damageable_player(candidate):
			continue

		var distance = candidate.global_position.distance_to(origin)
		if distance > radius:
			continue

		rpc("deal_damage", candidate.get_multiplayer_authority(), damage)


func try_activate_dash():
	if dash_speed <= 0.0 or dash_duration <= 0.0:
		return false
	if not is_ability_ready("dash"):
		return false

	var input_vector = Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")
	var local_direction = Vector3(input_vector.x, 0, input_vector.y)
	if local_direction.length_squared() == 0.0:
		local_direction = Vector3(0, 0, -1)
	else:
		local_direction = local_direction.normalized()

	dash_direction = local_direction.rotated(Vector3.UP, rotation.y).normalized()
	dash_timer = dash_duration
	vertical_velocity = max(vertical_velocity, 0.0)
	start_ability_cooldown("dash", dash_cooldown)
	return true


func respawn():
	health = max_health
	global_position = Lobby.get_spawn_position_for_peer(get_multiplayer_authority())
	horizontal_velocity = Vector3.ZERO
	vertical_velocity = 0.0
	jump_count = 0
	dash_timer = 0.0
	health_changed.emit(health)


func on_eliminated():
	pass


func _tick_ability_cooldowns(delta):
	for ability_name in ability_cooldowns.keys():
		var remaining = max(ability_cooldowns[ability_name] - delta, 0.0)
		if remaining <= 0.0:
			ability_cooldowns.erase(ability_name)
		else:
			ability_cooldowns[ability_name] = remaining


func _toggle_pause():
	if isPaused:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		isPaused = false
		pause_menu.hide()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		isPaused = true
		pause_menu.show()


func _get_desired_world_velocity():
	var input_vector = Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")
	var local_velocity = Vector3(
		input_vector.x * speed * strafe_speed_multiplier,
		0,
		input_vector.y * speed
	)

	if local_velocity.length() > speed * max(strafe_speed_multiplier, 1.0):
		local_velocity = local_velocity.normalized() * speed * max(strafe_speed_multiplier, 1.0)

	isMoving = local_velocity.length_squared() > 0.01
	return local_velocity.rotated(Vector3.UP, rotation.y)


func _handle_jump():
	if is_on_floor():
		vertical_velocity = jump_impulse
		jump_count = 1
		return

	if allow_double_jump and jump_count < 2:
		vertical_velocity = double_jump_impulse
		jump_count += 1


@rpc("call_local")
func deal_damage(peer_id, amount):
	var target_player = Lobby.get_node_from_peer_id(peer_id)
	if target_player == null:
		return
	target_player.receive_damage(amount)


@rpc("call_local")
func play_shoot_effects():
	pass


@rpc("any_peer")
func receive_damage(amount):
	health -= amount
	if health <= 0:
		on_eliminated()
		respawn()
		return

	health_changed.emit(health)


func _physics_process(delta):
	if not is_multiplayer_authority():
		return

	_tick_ability_cooldowns(delta)

	rotation.y = deg_to_rad(yaw)
	camera.rotation.x = deg_to_rad(pitch)

	if Input.is_action_just_pressed("escape"):
		_toggle_pause()

	if Input.is_action_just_pressed("reset"):
		respawn()

	if isPaused:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if Input.is_action_just_pressed("jump"):
		_handle_jump()

	if dash_timer > 0.0:
		dash_timer = max(dash_timer - delta, 0.0)
		horizontal_velocity = dash_direction * dash_speed
	else:
		var desired_velocity = _get_desired_world_velocity()
		var acceleration = ground_acceleration if is_on_floor() else air_acceleration
		horizontal_velocity = horizontal_velocity.move_toward(desired_velocity, acceleration * delta)

	if is_on_floor():
		if vertical_velocity < 0.0:
			vertical_velocity = -0.1
	else:
		if dash_timer <= 0.0:
			vertical_velocity -= fall_acceleration * delta

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	velocity.y = vertical_velocity
	move_and_slide()

	horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	vertical_velocity = velocity.y

	if is_on_floor() and velocity.y <= 0.0:
		jump_count = 0
