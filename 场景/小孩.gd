extends Interactable
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	animation_player.play("idle")

func interact() -> void:
	
	Dialogic.start("小孩对话")
