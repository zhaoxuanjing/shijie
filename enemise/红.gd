# 继承自Enemy类，实现敌人AI状态机
extends Enemy

# 定义敌人状态枚举
enum State {
	IDLE,     # 空闲状态
	WALK,     # 行走状态
	RUN,      # 奔跑状态
	ATTACK,   # 攻击状态
	HURT,     # 受伤状态
	DYING     # 死亡状态
}

# 常量定义
const KNOCKBACK_AMOUNT := 512.0  # 击退力度

# 状态相关变量
var pending_damage: Damage = null         # 待处理的伤害数据
var previous_state: State = State.IDLE    # 记录受伤前的状态
var has_attacked: bool = false            # 攻击标志位，标记是否已进行首次攻击

# 场景节点引用
@onready var floor_checker: RayCast2D = $Graphics/Sprite2D/FloorChecker
@onready var wall_checker: RayCast2D = $Graphics/Sprite2D/WallChecker
@onready var player_checker: RayCast2D = $Graphics/Sprite2D/PlayerChecker
@onready var player_checker_2: RayCast2D = $Graphics/Sprite2D/PlayerChecker2
@onready var attack_checker: RayCast2D = $Graphics/Sprite2D/AttackChecker
@onready var calm_down_timer: Timer = $CalmDownTimer


# 物理状态处理（每帧调用）
func tick_physics(state: State, delta: float) -> void:
	match state:
		# 静止类状态处理
		State.IDLE, State.HURT, State.DYING:
			move(0.0, delta)  # 停止移动
			
		# 行走状态处理
		State.WALK:
			move(max_speed / 3, delta)  # 以1/3速度移动
			
		# 奔跑状态处理
		State.RUN:
			# 边缘检测防止掉落
			if not floor_checker.is_colliding():
				@warning_ignore("int_as_enum_without_cast")
				direction *= -1  # 调转方向
			move(max_speed, delta)  # 全速移动
			# 进入攻击范围启动冷却
			if attack_checker.is_colliding():
				calm_down_timer.start()
				
		# 攻击状态处理
		State.ATTACK:  
			move(0.0, delta)  # 停止移动
			# 根据玩家位置调整方向
			if player_checker.is_colliding():
				var player_position = player_checker.get_collision_point()
				var direction_to_player = sign(player_position.x - global_position.x)
				if direction_to_player != direction:
					direction = direction_to_player  # 面向玩家

# 状态转移判断逻辑
func get_next_state(state: State) -> int:
	# 优先处理死亡状态
	if stats.health == 0:
		return StateMachine.KEEP_CURRENT if state == State.DYING else State.DYING
	
	# 处理待接收伤害
	if pending_damage:
		return State.HURT
	
	# 攻击条件判断（奔跑时进入攻击范围）
	if state == State.RUN and attack_checker.is_colliding():
		return State.ATTACK
	
	# 状态转换主逻辑
	match state:
		State.IDLE:
			# 空闲2秒后转为行走
			if state_machine.state_time > 2:
				return State.WALK
				
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
			# 攻击状态持续1秒处理
			if state_machine.state_time >= 1.0:
				has_attacked = true  # 标记已攻击
				return State.RUN if stats.health > 0 else State.IDLE
			
			# 玩家脱离攻击范围
			if not attack_checker.is_colliding():  
				return State.RUN
		
		State.HURT:
			# 受伤动画结束后恢复
			if not animation_player.is_playing():
				pending_damage = null
				return previous_state  # 返回受伤前状态
				
	return StateMachine.KEEP_CURRENT  # 默认保持当前状态

# 状态切换处理
func transition_state(from: State, to: State) -> void:
	# 打印状态转换日志
	print("[%s] %s => %s" %[
		Engine.get_physics_frames(),
		State.keys()[from] if from != -1 else "<START>",
		State.keys()[to],
	])
	
	# 记录非受伤状态的历史状态
	if to != State.HURT:
		previous_state = from
	
	# 状态切换具体处理
	match to:
		State.IDLE:
			animation_player.play("idle")  # 播放空闲动画
			# 处理面朝墙壁的情况
			if wall_checker.is_colliding():
				@warning_ignore("int_as_enum_without_cast")
				direction *= -1
				
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
			animation_player.play("attack")  # 播放攻击动画
		
		State.HURT:
			animation_player.play("hurt")  # 播放受伤动画
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
			animation_player.play("diying")  # 播放死亡动画

# 受伤区域信号回调



func _on_hurtbox_hurt(hitbox: Variant) -> void:
	pending_damage = Damage.new()
	pending_damage.amount = 1               # 伤害值
	pending_damage.source = hitbox.owner     # 伤害来源

