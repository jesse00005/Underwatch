extends CharacterBody3D
class_name Player

signal health_changed(health_value)

@export var speed = 2.5
@export var fall_acceleration = 30
@export var jump_impulse = 5
@export var projectile_scene : PackedScene = preload("res://projectile.tscn")
@export var shoot_offset = Vector3(.1, .3, 0)
@export var weapon_damage = 60
@onready var isMoving = false
@onready var pause_menu = $PauseMenu
@onready var raycast = $Camera3D/RayCast3D
@export var max_health = 300
@export var health = 300
var last_shot_time = 0.0
var shoot_cooldown = 0.5


@export var mouse_sensitivity = .2
@onready var camera = $Camera3D
@onready var isPaused = false

var yaw = 0.0
var pitch = 0.0

var target_velocity = Vector3.ZERO

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	if not is_multiplayer_authority():
		return
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.current = true
	last_shot_time = -shoot_cooldown


@rpc("call_local")
func deal_damage(peer_id, amount):
	var target_player = Lobby.get_node_from_peer_id(peer_id)
	target_player.receive_damage(amount)


@rpc("call_local")
func play_shoot_effects():
	pass

@rpc("any_peer")
func receive_damage(amount): 
	health -= amount
	if health <= 0:
		health = max_health
		position = Vector3.ZERO
	health_changed.emit(health)

	

func _physics_process(delta):
	if not is_multiplayer_authority():
		return
	var direction = Vector3.ZERO
	
	rotation.y = deg_to_rad(yaw)
	camera.rotation.x = deg_to_rad(pitch)
	
	if Input.is_action_pressed("strafe_right"):
		direction.x += 1
	if Input.is_action_pressed("strafe_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_back"):
		direction.z += 1
	if Input.is_action_pressed("move_forward"):
		direction.z -= 1	
		
	if Input.is_action_just_pressed("escape"):
		if isPaused:
			
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			isPaused = false
			pause_menu.hide()
			
		elif !isPaused:
			
			
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			isPaused = true
			pause_menu.show()
			
	if Input.is_action_just_pressed("reset"):
		position = Vector3.ZERO
			
	if direction != Vector3.ZERO:
		isMoving = true
		direction = direction.normalized()
		direction = direction.rotated(Vector3.UP, rotation.y)
		


		
		#$Pivot.basis = Basis.looking_at(direction)
	elif direction == Vector3.ZERO:
		isMoving = false

			
	target_velocity.x = direction.x * speed
	target_velocity.z = direction.z * speed
	

	if not is_on_floor():
		target_velocity.y = target_velocity.y - (fall_acceleration * delta)
		
	
		
	velocity = target_velocity
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		target_velocity.y = jump_impulse
		
	
				
	move_and_slide()
