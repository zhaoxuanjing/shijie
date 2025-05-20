class_name StateMachine
extends Node

const KEEP_CURRENT = -1

var current_state: int = -1 :
	set(v):
		owner.transition_state(current_state,v)
		current_state = v
		state_time = 0

var state_time:float

func _ready() -> void:
	# godot中子节点ready后父节点才ready，此处等待父节点ready后再执行后续代码
	await owner.ready
	current_state = 0


func _physics_process(delta: float) -> void:
	while true:
		var next := owner.get_next_state(current_state) as int
		if next == KEEP_CURRENT:
			break
		current_state = next
	
	owner.tick_physics(current_state,delta)
	state_time += delta
