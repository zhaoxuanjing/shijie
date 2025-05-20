# 定义一个继承自Enemy类的脚本，实现敌人的状态机和行为逻辑
extends Enemy

# 枚举敌人可能的状态（移除了ATTACK2）
enum State {
	IDLE,    # 空闲状态：静止不动
	WALK,    # 行走状态：缓慢移动
	RUN,     # 奔跑状态：快速追击玩家
	ATTACK,  # 攻击状态：近战攻击
	HURT,    # 受伤状态：受到攻击时的反应
	DYING    # 死亡状态：播放死亡动画
}

# 定义常量参数
const KNOCKBACK_AMOUNT := 512.0  # 被击退时的力度
const GRAVITY := 980.0           # 重力值

# 状态相关变量
var pending_damage: Damage = null   # 待处理的伤害数据
var previous_state: State = State.IDLE  # 前一个状态（用于状态恢复）

# 获取场景中的节点引用
@onready var floor_checker: RayCast2D = $Graphics/Sprite2D/FloorChecker
@onready var wall_checker: RayCast2D = $Graphics/Sprite2D/WallChecker
@onready var player_checker: RayCast2D = $Graphics/Sprite2D/PlayerChecker
@onready var attack_checker: RayCast2D = $Graphics/Sprite2D/AttackChecker
@onready var calm_down_timer: Timer = $CalmDownTimer

# 物理处理函数（每帧调用）
func tick_physics(state: State, delta: float) -> void:
	match state:
		# 静止类状态：停止移动
		State.IDLE, State.HURT, State.DYING, State.ATTACK:
			move(0.0, delta)
		
		# 行走状态：低速移动并检测地面
		State.WALK:
			if floor_checker.is_colliding():
				move(max_speed / 3, delta)
			else:
				direction *= -1
		
		# 奔跑状态：高速追击玩家
		State.RUN:
			if player_checker.is_colliding():
				var player_position = player_checker.get_collision_point()
				var direction_to_player = sign(player_position.x - global_position.x)
				direction = direction_to_player
			
			if not floor_checker.is_colliding():
				direction *= -1
			move(max_speed, delta)
			
			if attack_checker.is_colliding():
				calm_down_timer.start()

# 状态转移判断函数
func get_next_state(state: State) -> int:
	if stats.health == 0:
		return StateMachine.KEEP_CURRENT if state == State.DYING else State.DYING
	
	if pending_damage:
		return State.HURT

	match state:
		State.IDLE:
			if state_machine.state_time > 2:
				return State.WALK
			elif player_checker.is_colliding():  
				return State.RUN
		
		State.WALK:
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				return State.IDLE
			elif player_checker.is_colliding():  
				return State.RUN
				
		State.RUN:
			if attack_checker.is_colliding():  
				return State.ATTACK
			
			if not player_checker.is_colliding():  
				return State.IDLE
		
		# 修改了ATTACK状态转移逻辑（移除了ATTACK2相关部分）
		State.ATTACK:
			if not animation_player.is_playing():
				return State.RUN if player_checker.is_colliding() else State.IDLE
		
		State.HURT:
			# 受伤动画结束后恢复状态
			if not animation_player.is_playing():
				pending_damage = null  # 清空伤害数据
				return State.RUN if player_checker.is_colliding() else State.IDLE

	return StateMachine.KEEP_CURRENT

# 状态转换处理函数
func transition_state(from: State, to: State) -> void:
	print("[%s] %s => %s" % [
		Engine.get_physics_frames(),
		State.keys()[from] if from != -1 else "<START>",
		State.keys()[to],
	])

	if to != State.HURT:
		previous_state = from

	match to:
		State.IDLE:
			animation_player.play("idle")
		
		State.WALK:
			animation_player.play("walk")
			if not floor_checker.is_colliding():
				@warning_ignore("int_as_enum_without_cast")
				direction *= -1
				floor_checker.force_raycast_update()
		
		State.RUN:
			animation_player.play("run")
			if player_checker.is_colliding():
				var player_position = player_checker.get_collision_point()
				var direction_to_player = sign(player_position.x - global_position.x)
				if direction_to_player != direction:
					direction = direction_to_player
		
		State.ATTACK:
			animation_player.play("attack")
		
		State.HURT:
			animation_player.play("hurt") 
			if pending_damage:
				stats.health -= pending_damage.amount
				var dir := pending_damage.source.global_position.direction_to(global_position)
				velocity = dir * KNOCKBACK_AMOUNT
				if dir.x > 0:
					direction = Direction.LEFT
				else:
					direction = Direction.RIGHT
				pending_damage = null
		
		State.DYING:
			animation_player.play("death")
func handle_hurt():
	if pending_damage:
		# 应用伤害
		stats.health -= pending_damage.amount
		# 计算击退方向
		var dir = pending_damage.source.global_position.direction_to(global_position)
		velocity = dir * KNOCKBACK_AMOUNT  # 设置击退速度
		pending_damage = null              # 清空待处理伤害
# 移动控制函数
func move(speed: float, delta: float) -> void:
	velocity.x = direction * speed
	velocity.y += GRAVITY * delta
	set_velocity(velocity)
	move_and_slide()
	velocity = velocity

func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner
