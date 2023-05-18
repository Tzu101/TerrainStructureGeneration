extends CharacterBody2D


const AIR_FRICTION = 100
const GROUND_FRICTION = 500
const GLIDE_COEFICIENT = 0.1
const GRAVITY = 300
const MAX_GRAVITY = 900

const SPEED = 45
const MAX_SPEED = 90
const JUMP_POWER = 150
const MAX_JUMPS = INF
const MAX_GLIDE_TIME = INF

var jumps_left = MAX_JUMPS
var glide_time = 0

var is_grounded = null
var is_gliding = null
var flip_sprite = false
var direction = Vector2.ZERO

var still_time = 0
@onready var spriteSheet = $Spritesheet
@onready var animationPlayer = $AnimationPlayer

func animation_play(animation_name: String) -> void:
	if (animationPlayer.assigned_animation != animation_name):
		animationPlayer.play(animation_name)
	
func same_direction(number1: float, number2: float) -> bool:
	return (number1 * number2) > 0

func _ready():
	up_direction = Vector2.UP

func _process(delta):
	var animation_name: String = 'snooze' if still_time > 16 else 'idle'
	if not is_grounded:
		still_time = 0
		
		if velocity.y > JUMP_POWER:
			animation_name = 'fall'
		elif is_gliding:
			animation_name = 'glide'
		else:
			animation_name = 'jump'
		
	elif direction.x:
		still_time = 0
		
		if abs(velocity.x) >= MAX_SPEED and same_direction(direction.x, velocity.x):
			animation_name = 'run'
		else:
			animation_name = 'walk'
	else:
		still_time += delta
	
	if direction.x < 0:
		flip_sprite = true
	elif direction.x > 0:
		flip_sprite = false
	
	spriteSheet.flip_h = flip_sprite
	animation_play(animation_name)
	
func _physics_process(delta):
	
	# Get input
	is_grounded = is_on_floor()
	direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	
	# Horizontal movement
	if direction.x:
		velocity.x = move_toward(velocity.x, direction.x * MAX_SPEED, SPEED * delta)
	
	# Horizontal friction
	if not direction.x or not same_direction(direction.x, velocity.x):
		if is_grounded:
			velocity.x = move_toward(velocity.x, 0, GROUND_FRICTION * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, AIR_FRICTION * delta)
	
	# Jump
	if is_grounded:
		jumps_left = MAX_JUMPS
		glide_time = 0
	
	var is_jumping = Input.is_action_just_pressed('ui_up')
	if is_jumping and jumps_left > 0:
		jumps_left -= 1
		velocity.y = -JUMP_POWER
		
	# Glide
	var max_gravity = MAX_GRAVITY
	is_gliding = glide_time < MAX_GLIDE_TIME and direction.y < 0 and velocity.y > 0 and not is_grounded
	if is_gliding:
		glide_time += delta
		max_gravity = GRAVITY * GLIDE_COEFICIENT
	
	# Gravity
	if velocity.y < max_gravity:
		velocity.y = move_toward(velocity.y, MAX_GRAVITY, GRAVITY * delta)
	
	move_and_slide()
