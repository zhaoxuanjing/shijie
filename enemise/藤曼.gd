# 继承自Enemy类，实现敌人AI状态机
extends Enemy

# 定义敌人状态枚举
enum State {
	IDLE, 
	ATTACK    # 空闲状态
}

@onready var attack_timer: Timer = $AttackTimer


var pending_damage: Damage = null         # 待处理的伤害数据
var previous_state: State = State.IDLE    # 记录受伤前的状态
var has_attacked: bool = false            # 攻击标志位，标记是否已进行首次攻击

# 物理状态处理（每帧调用）
func tick_physics(state: State, delta: float) -> void:
	match state:
		# 攻击状态处理
		State.ATTACK:  
			move(0.0, delta)  # 停止移

func get_next_state(state: State) -> int:
	
	# 状态转换主逻辑
	match state:
		
		State.ATTACK:  
			# 攻击状态持续1秒处理
			if state_machine.state_time >= 0.5:
				has_attacked = true  # 标记已攻
	return StateMachine.KEEP_CURRENT  # 默认保持当前状态

# 状态切换处理
func transition_state(from: State, to: State) -> void:
	# 状态切换具体处理
	match to:
		State.IDLE:
			animation_player.play("idle")  # 播放空闲动画
			# 处理面朝墙壁的情况
				
		State.ATTACK:  
			animation_player.play("attack")  # 播放攻击动画



