extends RigidBody3D

@export var speed = 5
var lifetime = 5.0
# Called when the node enters the scene tree for the first time.
func _ready():
	linear_velocity = transform.basis.z * -speed
	
	set_deferred("queue_free", lifetime)
