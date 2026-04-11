extends Node3D

@export var gravity = 18.0
@export var lifetime = 2.0
@export var explosion_duration = 0.24

@onready var grenade_mesh = $GrenadeMesh
@onready var explosion_flash = $ExplosionFlash
@onready var impact_sound = $ImpactSound

var owner_peer_id = 1
var explosion_radius = 3.8
var explosion_damage = 75
var velocity = Vector3.ZERO
var elapsed = 0.0
var exploded = false
var explosion_timer = 0.0


func _ready():
	explosion_flash.visible = false
	explosion_flash.scale = Vector3.ONE * 0.01


func setup(spawn_position, throw_direction, new_owner_peer_id, launch_speed, upward_boost, radius, damage):
	global_position = spawn_position
	owner_peer_id = new_owner_peer_id
	explosion_radius = radius
	explosion_damage = damage
	velocity = throw_direction.normalized() * launch_speed
	velocity.y += upward_boost


func _physics_process(delta):
	if exploded:
		explosion_timer = max(explosion_timer - delta, 0.0)
		if explosion_timer <= 0.0:
			queue_free()
		return

	elapsed += delta
	if elapsed >= lifetime:
		_explode(global_position)
		return

	var previous_position = global_position
	velocity.y -= gravity * delta
	var next_position = previous_position + velocity * delta
	var hit = _raycast_to(next_position)

	if not hit.is_empty():
		_explode(hit.position)
		return

	global_position = next_position
	rotate_object_local(Vector3.RIGHT, delta * 10.0)
	rotate_object_local(Vector3.FORWARD, delta * 7.0)


func _raycast_to(next_position):
	var query = PhysicsRayQueryParameters3D.create(global_position, next_position)
	query.collide_with_areas = false
	query.collision_mask = 3
	var owner_player = Lobby.get_node_from_peer_id(owner_peer_id)
	if owner_player != null:
		query.exclude = [owner_player]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _explode(explosion_position):
	if exploded:
		return

	exploded = true
	global_position = explosion_position
	grenade_mesh.visible = false
	explosion_flash.visible = true
	explosion_flash.scale = Vector3.ONE * max(explosion_radius * 1.1, 2.5)
	impact_sound.play()
	explosion_timer = explosion_duration

	if multiplayer.get_unique_id() != owner_peer_id:
		return

	var owner_player = Lobby.get_node_from_peer_id(owner_peer_id)
	if owner_player == null:
		return
	if not owner_player.has_method("deal_radial_damage"):
		return

	owner_player.deal_radial_damage(global_position, explosion_radius, explosion_damage)
