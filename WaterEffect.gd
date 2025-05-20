extends Node2D
@onready var com_game_vp: SubViewport = $CanvasLayer/Control/SubViewportContainer/GameVP
@onready var com_water_vp: SubViewport = $CanvasLayer/Control/SubViewportContainer2/WaterVP


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	com_water_vp.world_2d = com_game_vp.world_2d
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
