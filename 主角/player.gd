class_name Player
extends CharacterBody2D
enum Direction{
	LEFT = -1,
	Right = +1,
}
enum State {
	IDLE,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
	WALL_SLIDING,
	WALL_JUMP,
	ATTACK_1,
	ATTACK_2,
	ATTACK_3,
	HURT,
	DYING
}

const GROUND_STATES := [
	State.IDLE, State.RUNNING, State.LANDING, 
	State.ATTACK_1, State.ATTACK_2, State.ATTACK_3
]

const KNOCKBACK_AMOUNT = 100
const RUN_SPEED := 140.0
const FLOOR_ACCELERATION := RUN_SPEED / 0.2
const AIR_ACCELERATION := RUN_SPEED / 0.1
const JUMP_VELOCITY := -340.0
const WALL_JUMP_VELOCITY = Vector2(380, -280)

@export var can_combo := false
@export var direction := Direction.Right:
	set(v):
		direction = v
		if not is_node_ready():
			await ready
		graphics.scale.x = direction

var default_gravity := ProjectSettings.get_setting("physics/2d/default_gravity") as float
var is_first_tick := false
var is_combo_requested := false
var pending_damage: Damage
var interacting_with: Array[Interactable]


@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_request_timer: Timer = $JumpRequestTimer
@onready var hand_checker: RayCast2D = $Graphics/HandChecker
@onready var foot_checker: RayCast2D = $Graphics/FootChecker
@onready var state_machine: StateMachine = $StateMachine
@onready var stats: Node = Game.player_stats
@onready var inteaction_icon: AnimatedSprite2D = $InteactionIcon
@onready var game_over_screen: Control = $CanvasLayer/GameOverScreen
@onready var pause_screen: Control = $CanvasLayer/PauseScreen
@onready var invincible_timer: Timer = $InvincibleTimer




func _ready() -> void:
	stand(default_gravity,0.01)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
	
	if event.is_action_released("jump"):
		jump_request_timer.stop()
		if velocity.y < JUMP_VELOCITY / 2:
			velocity.y = JUMP_VELOCITY / 2
	
	if event.is_action_pressed("attack") and can_combo:
		is_combo_requested = true
	if event.is_action_pressed("interact") and interacting_with:
		interacting_with.back().interact()
	if event.is_action_pressed("pause"):
		pause_screen.show_pause()

func tick_physics(state: State, delta: float) -> void:
	inteaction_icon.visible = not interacting_with.is_empty()
	match state:
		State.IDLE:
			move(default_gravity, delta)
		
		State.RUNNING:
			move(default_gravity, delta)
		
		State.JUMP:
			move(0.0 if is_first_tick else default_gravity, delta)
		
		State.FALL:
			move(default_gravity, delta)
		
		State.LANDING:
			stand(default_gravity, delta)
		
		State.WALL_SLIDING:
			move(default_gravity / 3, delta)
			direction = Direction.LEFT if get_wall_normal().x < 0 else Direction.Right
			
		State.WALL_JUMP:
			if state_machine.state_time < 0.1:
				stand(0.0 if is_first_tick else default_gravity, delta)
				direction = Direction.LEFT if get_wall_normal().x < 0 else Direction.Right
			else:
				move(default_gravity, delta)
			
		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3:
			stand(default_gravity, delta)
			
		State.HURT, State.DYING:
			stand(default_gravity, delta)
	
	is_first_tick = false

func die() -> void:
	game_over_screen.show_game_over()

func register_interactable(v:Interactable) -> void:
	if state_machine.current_state == State.DYING:
		return
	if v in interacting_with:
		return
	interacting_with.append(v)
	
func unregister_interactable(v:Interactable) -> void:
	interacting_with.erase(v)

func move(gravity: float, delta: float) -> void:
	var movement := Input.get_axis("move_left", "move_right")
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, movement * RUN_SPEED, acceleration * delta)
	velocity.y += gravity * delta
	
	if not is_zero_approx(movement):
		direction = Direction.LEFT if movement < 0 else Direction.Right
	
	move_and_slide()

func can_wall_slide() -> bool:
	return is_on_wall() and hand_checker.is_colliding() and foot_checker.is_colliding()

func stand(gravity: float, delta: float) -> void:
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.y += gravity * delta
	
	move_and_slide()

func get_next_state(state: State) -> int:
	if stats.health == 0:
		return StateMachine.KEEP_CURRENT if state == State.DYING else State.DYING
	if pending_damage:
		return State.HURT
	var can_jump := is_on_floor() or coyote_timer.time_left > 0
	var should_jump := can_jump and jump_request_timer.time_left > 0
	if should_jump:
		return State.JUMP
	
	if state in GROUND_STATES and not is_on_floor():
		return State.FALL
	
	var movement := Input.get_axis("move_left", "move_right")
	var is_still := is_zero_approx(movement) and is_zero_approx(velocity.x)
	
	match state:
		State.IDLE:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1
			if not is_still:
				return State.RUNNING
		
		State.RUNNING:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1
			if is_still:
				return State.IDLE
		
		State.JUMP:
			if velocity.y >= 0:
				return State.FALL
		
		State.FALL:
			if is_on_floor():
				return State.LANDING if is_still else State.RUNNING
			if can_wall_slide():
				return State.WALL_SLIDING
			
		State.LANDING:
			if not is_still:
				return State.RUNNING
			if not animation_player.is_playing():
				return State.IDLE
		
		State.WALL_SLIDING:
			if jump_request_timer.time_left > 0:
				return State.WALL_JUMP
			if is_on_floor():
				return State.IDLE
			if not is_on_wall():
				return State.FALL
			
		State.WALL_JUMP:
			if can_wall_slide() and not is_first_tick:
				return State.WALL_SLIDING
			if velocity.y >= 0:
				return State.FALL
				
		State.ATTACK_1:
			if not animation_player.is_playing():
				return State.ATTACK_2 if is_combo_requested else State.IDLE
			
		State.ATTACK_2:
			if not animation_player.is_playing():
				return State.ATTACK_3 if is_combo_requested else State.IDLE
			
		State.ATTACK_3:
			if not animation_player.is_playing():
				return State.IDLE
			
		State.HURT:
			if not animation_player.is_playing():
				return State.IDLE
			
		State.DYING:
			if not animation_player.is_playing():
				return State.IDLE
			
	return StateMachine.KEEP_CURRENT

func transition_state(from: State, to: State) -> void:
	#print("[%s] %s => %s" % [
		#Engine.get_physics_frames(),
		#State.keys()[from] if from != -1 else "<START>",
		#State.keys()[to],
	#])
	if from not in GROUND_STATES and to in GROUND_STATES:
		coyote_timer.stop()
	
	match to:
		State.IDLE:
			animation_player.play("idle")
		
		State.RUNNING:
			animation_player.play("running")
		
		State.JUMP:
			animation_player.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
			jump_request_timer.stop()
			SoundManager.play_sfx("jump")
		
		State.FALL:
			animation_player.play("fall")
			if from in GROUND_STATES:
				coyote_timer.start()
		
		State.LANDING:
			animation_player.play("landing")
		
		State.WALL_SLIDING:
			animation_player.play("wall_sliding")
			
		State.WALL_JUMP:
			animation_player.play("jump")
			velocity = WALL_JUMP_VELOCITY
			velocity.x *= get_wall_normal().x
			jump_request_timer.stop()
			
		State.ATTACK_1:
			animation_player.play("attack_1")
			is_combo_requested = false
			SoundManager.play_sfx("attack")
		State.ATTACK_2:
			animation_player.play("attack_2")
			is_combo_requested = false
			SoundManager.play_sfx("attack")
		State.ATTACK_3:
			animation_player.play("attack_3")
			is_combo_requested = false
			SoundManager.play_sfx("attack")
		State.HURT:
			animation_player.play("hurt")
			#Input.start_joy_vibration(0, 0, 0.8, 0.8)
			Game.shake_camera(1)
			if pending_damage:
				stats.health -= pending_damage.amount
			
				var dir := pending_damage.source.global_position.direction_to(global_position)
				velocity = dir * KNOCKBACK_AMOUNT
			
				pending_damage = null
				invincible_timer.start()
			
				
		State.DYING:
			animation_player.play("die")
			interacting_with.clear()
	is_first_tick = true

func _on_hurtbox_1_hurt(hitbox: Variant) -> void:
	if invincible_timer.time_left > 0:
		return
	
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner





func _on_hitbox_hit(_hurtbox: Variant) -> void:
	Game.shake_camera(1)

	
	Engine.time_scale = 0.01
	await get_tree().create_timer(0.05, true, false, true).timeout
	Engine.time_scale = 1
