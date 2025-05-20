class_name Enemy
extends CharacterBody2D


@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var state_machine: StateMachine = $StateMachine
@onready var stats: Stats = $Stats


# 敌人面朝的方向
enum Direction {
	# 面向左边
	LEFT = -1,
	# 面向右边
	RIGHT = +1,
}

signal died

@export var direction := Direction.LEFT:
	set(v):
		direction = v
		# 等待节点ready
		if not is_node_ready():
			await ready
		graphics.scale.x = -direction


# 最大速度
@export var max_speed: float = 120
# 加速度
@export var acceleration: float = 1000
# 获取引擎给的重力加速度
var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float

func _ready() -> void:
	add_to_group("enemies")

func move(speed: float, delta: float) -> void:
	# 修改速度向量
	velocity.x = move_toward(velocity.x, speed * direction, acceleration * delta)
	velocity.y += default_gravity * delta


	move_and_slide()

func die() -> void:
	died.emit()
	queue_free()
