extends Node

const SAVE_PATH := "user://data.sav"
const CONFIG_PATH := "user://config.ini"

signal camera_should_shake(amount: float)



@onready var player_stats: Stats = $PlayerStats
@onready var color_rect: ColorRect = $ColorRect
@onready var default_player_stats := player_stats.to_dict()



# 场景的名称 => {
#   enemies_alive => [ 敌人的路径 ]
# }
var world_states := {}

# 记录玩家是否已经看过过场动画
var has_seen_intro := false

func _ready() -> void:
	color_rect.color.a = 0
	load_config()
	
func change_scene(path: String, params ={}) -> void:
	var tree := get_tree()
	tree.paused = true
	
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(color_rect, "color:a", 1, 0.2)
	await tween.finished
	
	
	if tree.current_scene is World:
		var old_name := tree.current_scene.scene_file_path.get_file().get_basename()
		world_states[old_name] = tree.current_scene.to_dict()
	tree.change_scene_to_file(path)
	
	if "init" in params:
		params.init.call()
	await tree.tree_changed
	await tree.process_frame
	
	if tree.current_scene is World:
		var new_name := tree.current_scene.scene_file_path.get_file().get_basename()
		if new_name in world_states:
			tree.current_scene.from_dict(world_states[new_name])
		if "EntryPoint" in params :
			for node in tree.get_nodes_in_group("entry_points"):
				if node.name == params.entry_point:
					tree.current_scene.update_player(node.global_position,node.direction)
					break
	
	if "position" in params and "direction" in params:
			tree.current_scene.update_player(params.position, params.direction)
	
	tree.paused = false
	
	tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(color_rect, "color:a", 0, 0.2)

func save_game() -> void:
	var scene := get_tree().current_scene
	var scene_name := scene.scene_file_path.get_file().get_basename()
	world_states[scene_name] = scene.to_dict()
	
	var data := {
		world_states=world_states,
		stats=player_stats.to_dict(),
		scene=scene.scene_file_path,
		player={
			direction=scene.player.direction,
			position={
				x=scene.player.global_position.x,
				y=scene.player.global_position.y,
			},
		},
	}
	var json := JSON.stringify(data)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_string(json)


func load_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	
	var json := file.get_as_text()
	var data := JSON.parse_string(json) as Dictionary
	
	# Load player stats and world states before changing scene
	world_states = data.world_states
	player_stats.from_dict(data.stats)
	
	change_scene(data.scene, {
		direction=data.player.direction,
		position=Vector2(
			data.player.position.x,
			data.player.position.y
		)
	})

func new_game() -> void:
	# Reset player stats first
	player_stats.from_dict(default_player_stats)
	world_states = {}
	change_scene("res://场景/场景一/world.tscn", {
		duration=1,
	}
	
	)
	
	
func back_to_title() -> void:
	change_scene("res://场景/t_itle_screen.tscn", {
		duration=1,
	})
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_config() -> void:
	var config := ConfigFile.new()
	
	config.set_value("audio", "master", SoundManager.get_volume(SoundManager.Bus.MASTER))
	config.set_value("audio", "sfx", SoundManager.get_volume(SoundManager.Bus.SFX))
	config.set_value("audio", "bgm", SoundManager.get_volume(SoundManager.Bus.BGM))
	config.set_value("game", "has_seen_intro", has_seen_intro)
	
	config.save(CONFIG_PATH)


func load_config() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	if err == OK:
		has_seen_intro = config.get_value("game", "has_seen_intro", false)
		SoundManager.set_volume(
			SoundManager.Bus.MASTER,
			config.get_value("audio", "master", 0.5)
		)
		SoundManager.set_volume(
			SoundManager.Bus.SFX,
			config.get_value("audio", "sfx", 1.0)
		)
		SoundManager.set_volume(
			SoundManager.Bus.BGM,
			config.get_value("audio", "bgm", 1.0)
		)

func shake_camera(amount: float) -> void:
	camera_should_shake.emit(amount)

# 检查是否需要播放过场动画
func should_play_intro() -> bool:
	return not has_seen_intro

# 标记过场动画已播放
func mark_intro_as_seen() -> void:
	has_seen_intro = true
	save_config()
