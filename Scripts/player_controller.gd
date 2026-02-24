extends CharacterBody2D

#JUMP----------
@export var speed = 350.0
@export var jump_power = 10
@export_range(0,1) var deceletate_on_jump_release = 0.5
var jump_multiplier = -30

#MOVEMENT----------
var direction = 0
@export_range(0,1) var deceleration = 0.1
@export_range(0,1) var aceleration = 0.1

#ANIMATION----------
var current_anim = ""
@onready var animation_player = $Animator/AnimationPlayer
@onready	var animated_sprite = $Animator/AnimatedSprite2D

#DASH----------
@export var dash_speed = 1000.0
@export var dash_max_distance = 300.0
@export var dash_cooldown = 1.0
@export var dash_curve : Curve
var is_dashing = false
var dash_start_position = 0
var dash_direction = 0
var dash_timer = 0


func _ready():
	animation_player.play("Idle")
	current_anim = "Idle"


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = jump_power * jump_multiplier
		
	if Input.is_action_just_released("Jump") and velocity.y <0:
		velocity.y *= deceletate_on_jump_release
		

	# Movement
	direction = Input.get_axis("move_left", "move_right")
 #move left and right and acelerate or desacelerate on start/end of the move
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * speed, speed * aceleration)
		animated_sprite.play("Running")
		animated_sprite.flip_h = direction<0
	else:
		velocity.x = move_toward(velocity.x, 0, speed * deceleration)
		animated_sprite.play("Idle")

#dash activation
	if Input.is_action_just_pressed("Dash") and direction and not is_dashing and dash_timer <=0:
		is_dashing = true
		dash_start_position = position.x
		dash_direction = direction
		dash_timer = dash_cooldown
	
#dashing
	if is_dashing:
		var current_distance = abs(position.x - dash_start_position)
		if current_distance >= dash_max_distance or is_on_wall():
			is_dashing = false
		else:
			velocity.x = dash_direction * dash_speed * dash_curve.sample(current_distance/dash_max_distance)
			velocity.y = 0

#reducing the dash timer
	if dash_timer > 0:
		dash_timer -= delta

	move_and_slide()
