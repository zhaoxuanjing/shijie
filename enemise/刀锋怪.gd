# 定义一个继承自Enemy类的脚本，实现敌人的状态机和行为逻辑
extends Enemy

# 枚举敌人可能的状态
enum State {
	IDLE,    # 空闲状态：静止不动
	WALK,    # 行走状态：缓慢移动
	RUN,     # 奔跑状态：快速追击玩家
	ATTACK,  # 第一次攻击状态：近战攻击
	ATTACK2, # 第二次攻击状态：连击攻击
	HURT,    # 受伤状态：受到攻击时的反应
	DYING    # 死亡状态：播放死亡动画
}

# 定义常量参数
const KNOCKBACK_AMOUNT := 300 # 被击退时的力度
const ATTACK_DELAY := 0.4        # 攻击之间的延迟时间（秒）
const GRAVITY := 980.0           # 重力值

# 状态相关变量
var pending_damage: Damage = null   # 待处理的伤害数据
var previous_state: State = State.IDLE  # 前一个状态（用于状态恢复）
var has_attacked: bool = false      # 攻击标记（是否已攻击）
var attack_delay_timer: Timer       # 攻击延迟计时器

# 获取场景中的节点引用
@onready var floor_checker: RayCast2D = $Graphics/Sprite2D/FloorChecker  # 地面检测射线
@onready var wall_checker: RayCast2D = $Graphics/Sprite2D/WallChecker    # 墙壁检测射线
@onready var player_checker: RayCast2D = $Graphics/Sprite2D/PlayerChecker # 玩家检测射线
@onready var attack_checker: RayCast2D = $Graphics/Sprite2D/AttackChecker # 攻击范围检测射线
@onready var calm_down_timer: Timer = $CalmDownTimer  # 冷静计时器（攻击后冷却）
@onready var attack_timer: Timer = $AttackTimer       # 攻击计时器

# 初始化函数
func _ready():
	# 创建并配置攻击延迟计时器
	attack_delay_timer = Timer.new()
	attack_delay_timer.one_shot = true        # 单次触发模式
	attack_delay_timer.wait_time = ATTACK_DELAY # 设置等待时间
	attack_delay_timer.timeout.connect(_on_attack_delay_timeout)  # 连接超时信号
	add_child(attack_delay_timer)             # 添加到场景树

# 物理处理函数（每帧调用）
func tick_physics(state: State, delta: float) -> void:
	match state:
		# 静止类状态：停止移动
		State.IDLE, State.HURT, State.DYING, State.ATTACK, State.ATTACK2:
			move(0.0, delta)  # 速度为0的移动
		
		# 行走状态：低速移动并检测地面
		State.WALK:
			if floor_checker.is_colliding():  # 如果检测到地面
				move(max_speed / 3, delta)    # 以1/3最大速度移动
			else:
				direction *= -1              # 否则调头
		
		# 奔跑状态：高速追击玩家
		State.RUN:
			if player_checker.is_colliding():  # 如果检测到玩家
				# 计算玩家方向并调整移动方向
				var player_position = player_checker.get_collision_point()
				var direction_to_player = sign(player_position.x - global_position.x)
				direction = direction_to_player
			
			# 边缘检测（防止掉落）
			if not floor_checker.is_colliding():
				direction *= -1  # 调头
			move(max_speed, delta)  # 全速移动
			
			# 如果进入攻击范围，启动冷静计时器
			if attack_checker.is_colliding():
				calm_down_timer.start()
# 状态转移判断函数
func get_next_state(state: State) -> int:
	# 优先处理死亡状态
	if stats.health == 0:
		return StateMachine.KEEP_CURRENT if state == State.DYING else State.DYING
	
	# 处理待处理伤害
	if pending_damage:
		return State.HURT

	# 根据当前状态判断下一个状态
	match state:
		State.IDLE:
			# 空闲2秒后转为行走
			if state_machine.state_time > 2:
				return State.WALK
			elif player_checker.is_colliding():  
				return State.RUN
		
		State.WALK:
			# 障碍物检测
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				return State.IDLE
			# 检测到玩家进入奔跑
			elif player_checker.is_colliding():  
				return State.RUN
				
		
		State.RUN:
		# 攻击范围内保持攻击状态
			if attack_checker.is_colliding():  
				return State.ATTACK
			
			# 丢失玩家视野处理
			if not player_checker.is_colliding():  
				if has_attacked:
					has_attacked = false  # 重置攻击标志
					return State.RUN      # 保持追击状态
				else:
					return State.IDLE    # 返回空闲
		
		State.ATTACK:
			# 攻击动画结束后判断连击
			if not animation_player.is_playing():
				if attack_checker.is_colliding():  # 仍在攻击范围
					attack_delay_timer.start()      # 启动攻击延迟
					return State.ATTACK2            # 进行第二次攻击
				elif player_checker.is_colliding(): # 玩家仍在追踪范围
					return State.RUN
				else:
					return State.IDLE              # 返回空闲
		
		State.ATTACK2:
			# 连击结束后判断状态
			if not animation_player.is_playing():
				return State.RUN if player_checker.is_colliding() else State.IDLE
		
		State.HURT:
			# 受伤动画结束后恢复状态
			if not animation_player.is_playing():
				pending_damage = null  # 清空伤害数据
				return State.RUN if player_checker.is_colliding() else State.IDLE

	return StateMachine.KEEP_CURRENT  # 保持当前状态

# 状态转换处理函数
func transition_state(from: State, to: State) -> void:
	# 打印状态转换日志
	print("[%s] %s => %s" % [
		Engine.get_physics_frames(),
		State.keys()[from] if from != -1 else "<START>",
		State.keys()[to],
	])

	# 记录前一个状态（非受伤状态时）
	if to != State.HURT:
		previous_state = from

	# 根据目标状态执行相应操作
	match to:
		State.IDLE:
			animation_player.play("idle")  # 播放空闲动画
		
		State.WALK:
			animation_player.play("walk")  # 播放行走动画
			# 边缘检测方向调整
			if not floor_checker.is_colliding():
				@warning_ignore("int_as_enum_without_cast")
				direction *= -1
				floor_checker.force_raycast_update()  # 立即更新射线检测
		
		State.RUN:
			animation_player.play("run")  # 播放奔跑动画
			# 根据玩家位置转向
			if player_checker.is_colliding():
				var player_position = player_checker.get_collision_point()
				var direction_to_player = sign(player_position.x - global_position.x)
				if direction_to_player != direction:
					direction = direction_to_player
		
		State.ATTACK:
			animation_player.play("attack") # 播放攻击动画
		
		State.ATTACK2:
			animation_player.play("attack2") # 播放二次攻击动画
		
		State.HURT:
			animation_player.play("hurt") 
			# 处理伤害效果
			if pending_damage:
				stats.health -= pending_damage.amount  # 扣除生命值
				# 计算击退方向
				var dir := pending_damage.source.global_position.direction_to(global_position)
				velocity = dir * KNOCKBACK_AMOUNT
				# 根据击退方向调整面朝方向
				if dir.x > 0:
					direction = Direction.LEFT
				else:
					direction = Direction.RIGHT
				pending_damage = null
		
		State.DYING:
			animation_player.play("death") # 播放死亡动画

# 攻击延迟计时器回调
func _on_attack_delay_timeout():
	# 延迟结束后根据情况切换状态
	if attack_checker.is_colliding():
		get_next_state(State.ATTACK2)
	else:
		get_next_state(State.RUN)

# 受伤处理函数
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
	velocity.x = direction * speed        # 设置水平速度
	velocity.y += GRAVITY * delta         # 应用重力
	set_velocity(velocity)                # 设置物理引擎速度
	move_and_slide()                      # 执行移动
	velocity = velocity                   # 更新速度变量（保持垂直速度）



func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	pending_damage = Damage.new()
	pending_damage.amount = 1              # 设置伤害值
	pending_damage.source = hitbox.owner    # 记录伤害来源
