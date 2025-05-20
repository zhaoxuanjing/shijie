class_name World
extends Node2D
@export  var bgm: AudioStream

@onready var tile_map: TileMap = $TileMap
@onready var camera_2d: Camera2D = $player/Camera2D
@onready var player: CharacterBody2D = $player

func _ready() -> void:

	# 获取瓦片地图的范围
	var used := tile_map.get_used_rect()
	# 获取单个图块的尺寸
	var tile_size:=tile_map.tile_set.tile_size
	# 为相机的上下左右添加限制
	camera_2d.limit_top= used.position.y * tile_size.y
	camera_2d.limit_right= used.end.x * tile_size.x
	camera_2d.limit_bottom= used.end.y * tile_size.y
	camera_2d.limit_left= used.position.x * tile_size.x
	# 将相机的位置立即设置为其当前平滑的目标位置。
	camera_2d.reset_smoothing()
	
	if bgm:
		SoundManager.play_bgm(bgm)
	#
#func _unhandled_input(event: InputEvent) -> void:
	#if event.is_action_pressed("ui_cancel"):
		#Game.back_to_title()




func update_player(pos: Vector2, direction: Player.Direction) -> void:
	player.global_position = pos
	player.direction = direction
	camera_2d.reset_smoothing()
	camera_2d.force_update_scroll()  # 4.2 开始

func to_dict() -> Dictionary:
	var enemies_alive := []
	for node in get_tree().get_nodes_in_group("enemies"):
		var path := get_path_to(node) as String
		enemies_alive.append(path)
	
	return {
		enemies_alive=enemies_alive,
	}
func from_dict(dict: Dictionary) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var path := get_path_to(node) as String
		if path not in dict.enemies_alive:
			node.queue_free()
	
