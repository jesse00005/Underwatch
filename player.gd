extends CharacterBody3D

signal health_changed(health_value)

@export var speed = 2.5
@export var fall_acceleration = 30
@export var jump_impulse = 5
@onready var anim = $Pivot/peterrigged4/AnimationPlayer
@export var projectile_scene : PackedScene = preload("res://projectile.tscn")
@export var shoot_offset = Vector3(.1, .3, 0)
@export var weapon_damage = 60
@onready var isMoving = false
@onready var muzzle_flash = $Pivot/peterrigged4/MuzzleFlash
@onready var raycast = $Camera3D/RayCast3D
@onready var pause_menu = $PauseMenu
var max_health = 300
var health = 300
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

func _input(event):
	
	if not is_multiplayer_authority():
		return
	if !isPaused:
		if event is InputEventMouseMotion:
			yaw -= event.relative.x * mouse_sensitivity
			pitch -= event.relative.y * mouse_sensitivity
			pitch = clamp (pitch, -45.0, 90.0)
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and anim.current_animation != "shoot_run" and anim.current_animation != "shoot_still":
		#shoot_projectile()
			
			play_shoot_effects.rpc()
			if raycast.is_colliding():
				var hit_player = raycast.get_collider()
				hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())
			

@rpc("call_local")
func play_shoot_effects():
	$PeterGun.playing = true
	if isMoving:
			anim.play("shoot_run")
	elif !isMoving:
		anim.play("shoot_still")
	muzzle_flash.restart()

@rpc("any_peer")
func receive_damage():
	health -= weapon_damage
	if health <= 0:
		health = max_health
		position = Vector3.ZERO
		$peter_laugh.playing = true
	health_changed.emit(health)

func shoot_projectile():
	if not projectile_scene:
		print("Projectile scene not assigned!")
		return
	var projectile = projectile_scene.instantiate()
	projectile.position = camera.global_transform.origin + camera.global_transform.basis.z * -1.0
	var direction = -camera.global_transform.basis.z.normalized()
	#projectile.linear_velocity = direction * shoot_force
	get_tree().current_scene.add_child(projectile)
	

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
		
		if anim.current_animation != "shoot_run" and anim.current_animation != "shoot_still":
			anim.play("Object_4Action")	

		
		#$Pivot.basis = Basis.looking_at(direction)
	elif direction == Vector3.ZERO:
		isMoving = false
		anim.stop	
		if anim.current_animation != "shoot_still" and anim.current_animation != "shoot_run":
			anim.play("mixamo_com_Object_4")
			
	target_velocity.x = direction.x * speed
	target_velocity.z = direction.z * speed
	

	if not is_on_floor():
		target_velocity.y = target_velocity.y - (fall_acceleration * delta)
		
	
		
	velocity = target_velocity
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		target_velocity.y = jump_impulse
		
	
				
	move_and_slide()
