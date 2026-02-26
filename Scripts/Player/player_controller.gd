extends CharacterBody2D

#STATE MACHINE =================

enum STATE {
	FALL,
	FLOOR,
	JUMP,
	DOUBLE_JUMP,
	LEDGE_CLIMB,
	DASH
}

var active_state := STATE.FALL


#MOVEMENT =================

@export var speed := 600.0
@export_range(0,1) var acceleration := 0.1
@export_range(0,1) var deceleration := 0.1

var direction := 0.0
var facing_direction := 1.0


#JUMP =================

@export var jump_power := -600.0
@export var fall_gravity := 1500.0
@export var fall_velocity := 500.0

@onready var coyote_timer: Timer = %CoyoteTimer

var can_double_jump := false
const double_jump_velocity := -600.0


#LEDGE =================

@onready var player_collider: CollisionShape2D = %CollisionShape2D
@onready var ledge_climb_ray_cast: RayCast2D = %LedgeClimbRayCast
@onready var ledge_space_ray_cast: RayCast2D = %LedgeSpaceRayCast


#ANIMATION =================

@onready var animated_sprite: AnimatedSprite2D = $Animator/AnimatedSprite2D


#DASH =================

const dash_lenght := 250.0
const dash_velocity := 1000.0
@onready var dash_cooldown: Timer = %DashCooldown

var can_dash := false
var saved_position := Vector2.ZERO


#READY =================

func _ready():
	switch_state(active_state)
	ledge_climb_ray_cast.add_exception(self)


#PHYSICS =================

func _physics_process(delta: float) -> void:
	process_state(delta)

	if active_state == STATE.DASH:
		process_dash(delta)
	else:
		move_and_slide()


#STATE SWITCH =================

func switch_state(to_state: STATE) -> void:
	var previous_state := active_state
	active_state = to_state
	
	match active_state:
		
		STATE.FALL:
			if previous_state != STATE.DOUBLE_JUMP:
				animated_sprite.play("Falling")
			if previous_state == STATE.FLOOR:
				coyote_timer.start()
		
		STATE.FLOOR:
			can_double_jump = true
		
		STATE.JUMP:
			animated_sprite.play("Jump")
			velocity.y = jump_power
			coyote_timer.stop()
		
		STATE.DOUBLE_JUMP:
			animated_sprite.play("Double_Jump")
			velocity.y = double_jump_velocity
			can_double_jump = false
		
		STATE.LEDGE_CLIMB:
			animated_sprite.play("Climbing")
			velocity = Vector2.ZERO
			align_to_ledge()
		
		STATE.DASH:
			animated_sprite.play("Dashing")

			dash_cooldown.start()
			can_dash = false

			var input_dir = Input.get_axis("move_left", "move_right")
			if input_dir != 0:
				set_facing_direction(signf(input_dir))

			velocity = Vector2.ZERO
			saved_position = global_position


#STATE PROCESS =================

func process_state(delta: float) -> void:
	
	match active_state:
		
		STATE.FALL:
			velocity.y = move_toward(velocity.y, fall_velocity, fall_gravity * delta)
			handle_movement()
			
			if is_on_floor():
				switch_state(STATE.FLOOR)
			
			elif Input.is_action_just_pressed("Jump"):
				if coyote_timer.time_left > 0:
					switch_state(STATE.JUMP)
				elif can_double_jump:
					switch_state(STATE.DOUBLE_JUMP)
			
			elif is_input_toward_facing() and is_ledge() and is_space():
				switch_state(STATE.LEDGE_CLIMB)
				
			elif Input.is_action_just_pressed("Dash") and can_dash:
				switch_state(STATE.DASH)
		
		
		STATE.JUMP, STATE.DOUBLE_JUMP:
			velocity.y += fall_gravity * delta
			
			if Input.is_action_just_released("Jump") and velocity.y < 0:
				velocity.y *= 0.4
			
			handle_movement()
			
			if velocity.y > 0:
				switch_state(STATE.FALL)
			
			elif Input.is_action_just_pressed("Dash") and can_dash:
				switch_state(STATE.DASH)
		
		
		STATE.LEDGE_CLIMB:
			if not animated_sprite.is_playing():
				switch_state(STATE.FLOOR)
		
		
		STATE.DASH:
			# Movimento tratado em process_dash()
			
			if Input.is_action_just_pressed("Jump"):
				if is_on_floor() or coyote_timer.time_left > 0:
					switch_state(STATE.JUMP)
		
		
		STATE.FLOOR:
			handle_movement()
			can_dash = true
			
			if direction != 0:
				animated_sprite.play("Running")
			else:
				animated_sprite.play("Idle")
			
			if not is_on_floor():
				switch_state(STATE.FALL)
			
			elif Input.is_action_just_pressed("Jump"):
				switch_state(STATE.JUMP)
			
			elif Input.is_action_just_pressed("Dash") and can_dash:
				switch_state(STATE.DASH)


#DASH MOVEMENT =================

func process_dash(delta: float) -> void:
	
	var motion := Vector2(facing_direction * dash_velocity * delta, 0)
	var collision = move_and_collide(motion)

	if collision:
		velocity = Vector2.ZERO
		
		if is_on_floor():
			switch_state(STATE.FLOOR)
		else:
			switch_state(STATE.FALL)
		return

	var distance := absf(global_position.x - saved_position.x)

	if distance >= dash_lenght:
		velocity = Vector2.ZERO
		
		if is_on_floor():
			switch_state(STATE.FLOOR)
		else:
			switch_state(STATE.FALL)


#MOVEMENT =================

func handle_movement() -> void:
	
	direction = Input.get_axis("move_left", "move_right")
	
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * speed, speed * acceleration)
		animated_sprite.flip_h = direction < 0
		facing_direction = direction
		update_ledge_raycast_direction()
	else:
		velocity.x = move_toward(velocity.x, 0, speed * deceleration)


func update_ledge_raycast_direction():
	ledge_climb_ray_cast.position.x = abs(ledge_climb_ray_cast.position.x) * facing_direction
	ledge_climb_ray_cast.target_position.x = abs(ledge_climb_ray_cast.target_position.x) * facing_direction
	ledge_climb_ray_cast.force_raycast_update()


#LEDGE CHECKS =================

func is_input_toward_facing() -> bool:
	return signf(Input.get_axis("move_left", "move_right")) == facing_direction


func is_ledge() -> bool:
	return is_on_wall() \
	and ledge_climb_ray_cast.is_colliding() \
	and ledge_climb_ray_cast.get_collision_normal().is_equal_approx(Vector2.UP)


func is_space() -> bool:
	ledge_space_ray_cast.global_position = ledge_climb_ray_cast.get_collision_point()
	ledge_space_ray_cast.force_raycast_update()
	return not ledge_space_ray_cast.is_colliding()


#LEDGE ALIGNMENT =================

func align_to_ledge():
	var collision_point = ledge_climb_ray_cast.get_collision_point()
	var shape = player_collider.shape as CapsuleShape2D
	
	var half_height = shape.height * 0.5
	
	global_position.x = collision_point.x - (shape.radius * facing_direction) + 20
	global_position.y = collision_point.y - half_height - player_collider.position.y - 5
	
	velocity = Vector2.ZERO
	can_double_jump = true


#UTILITY =================

func set_facing_direction(dir: float) -> void:
	if dir != 0:
		animated_sprite.flip_h = dir < 0
		facing_direction = dir
		ledge_climb_ray_cast.position.x = dir * absf(ledge_climb_ray_cast.position.x)
		ledge_climb_ray_cast.target_position.x = dir * absf(ledge_climb_ray_cast.target_position.x)
		ledge_climb_ray_cast.force_raycast_update()
