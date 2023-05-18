extends CharacterBody2D

const SPEED = 400
const MAX_SPEED = 400

var flip_sprite = false
var direction = Vector2.ZERO
# var velocity = Vector2.ZERO

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
		
	if direction.x:
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
	
func _physics_process(_delta: float):
	
	# Get input
	direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	
	# Horizontal movement
	velocity.x = direction.x * SPEED
	
	# Vertical movement
	velocity.y = direction.y * SPEED
	
	# Update position
	move_and_slide()
