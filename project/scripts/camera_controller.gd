extends Camera3D


@export var sensitivity: float = 0.002
@export var speed: float = 10.0

var motion: Vector2 = Vector2.ZERO;
var pitch: float = 0.0
var velocity: Vector3 = Vector3.ZERO



func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		motion -= event.relative;
	if event is InputEventMouseButton  and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			speed += 1.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			speed = max(1.0, speed - 1.0)
		
	
func _process(_delta: float) -> void:
	var direction = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		direction -= global_transform.basis.z
	if Input.is_action_pressed("move_backward"):
		direction += global_transform.basis.z
	if Input.is_action_pressed("move_left"):
		direction -= global_transform.basis.x
	if Input.is_action_pressed("move_right"):
		direction += global_transform.basis.x
	if Input.is_action_pressed("move_up"):
		direction += Vector3.UP
	if Input.is_action_pressed("move_down"):
		direction -= Vector3.UP
		

	direction = direction.normalized()
	
	var target = direction * speed
	velocity = velocity.lerp(target, 15.0* _delta)
	global_position += velocity * _delta
	
	
	global_position += velocity * _delta
	global_rotate(Vector3.UP, motion.x * sensitivity)
	
	pitch += motion.y * sensitivity
	pitch = clamp(pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
	
	rotation.x = pitch
	motion = Vector2.ZERO
