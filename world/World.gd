extends Node2D
class_name World


const COSMOS := -1000
const CLOUDLAND := -400
const OVERWORLD := 0
const UNDERWORLD := 200
const ABYSS := 1000

static func position_to_chunk(world_position: Vector2) -> Vector2:
	return floor(world_position / Chunk.SIZE)

static func position_to_block(world_position: Vector2) -> Vector2:
	return floor(world_position / Block.SIZE)


var world_seed = 69 * 420
var world_name = 'Hello world'

var chunks: Dictionary
var worldManager: WorldManager

@onready var player := $Spectator

func _ready():
	GameFiles.init_game_files()
	WorldFiles.init_world_files(world_name)
	
	worldManager = WorldManager.new(chunks, world_seed, world_name, 6)
	worldManager.chunk_loaded.connect(_on_chunk_loaded)
	worldManager.chunk_unloaded.connect(_on_chunk_unloaded)

func _process(_delta : float):
	var player_chunk := World.position_to_chunk(player.position)
	worldManager.update(player_chunk)

func _on_chunk_loaded(chunk: Chunk):
	add_child(chunk)

func _on_chunk_unloaded(chunk: Chunk):
	chunk.queue_free()

func _exit_tree():
	worldManager.exit_tree()
