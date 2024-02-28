extends StaticBody2D
class_name Chunk


class Layers:
	var foreground: Array[Array]
	var background: Array[Array]
	
	func _init(_foreground: Array[Array], _background: Array[Array]):
		foreground = _foreground
		background = _background
	
	static func init_empty() -> Layers:
		var empty_foreground: Array[Array] = []
		empty_foreground.resize(BLOCK_NUM)
		
		var empty_background: Array[Array] = []
		empty_background.resize(BLOCK_NUM)

		for row in range(BLOCK_NUM):
			empty_foreground[row].resize(BLOCK_NUM)
			empty_foreground[row].fill(Block.Id.AIR)
			
			empty_background[row].resize(BLOCK_NUM)
			empty_background[row].fill(Block.Id.AIR)
		
		return Layers.new(empty_foreground, empty_background)


const BLOCK_NUM: int = 10
const SIZE: int = BLOCK_NUM * Block.SIZE

static func build(chunk: Chunk) -> void:
	chunk.position = chunk.local_position * Chunk.SIZE
	
	for row in range(Chunk.BLOCK_NUM):
		chunk.blocks.append([])
		for col in range(Chunk.BLOCK_NUM):
			
			var block_position = Vector2(col, row)
			var foreground_block_id = chunk.layers.foreground[row][col]
			var background_block_id = chunk.layers.background[row][col]
			
			if foreground_block_id != Block.Id.AIR:
				var block = Block.build(block_position, foreground_block_id)
				chunk.call_deferred("add_child", block)
				chunk.blocks[row].append(block)
			
			elif background_block_id != Block.Id.AIR:
				var block = Block.build(block_position, background_block_id)
				var block_background = BlockBackground.new()
				block.add_child(block_background)
				
				chunk.call_deferred("add_child", block)
				chunk.blocks[row].append(block)
			
			else:
				chunk.blocks[row].append(null)


var local_position: Vector2
var layers: Layers
var blocks: Array[Array] = []
var is_modified: bool = false

func _init(_local_position: Vector2, _layers: Layers):
	local_position = _local_position
	layers = _layers
