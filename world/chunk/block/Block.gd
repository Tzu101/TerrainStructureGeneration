extends CollisionShape2D
class_name Block


const SIZE: int = 20

enum Template {
	NONE=0,
	OVERWORLD_ABOVEGROUND=1,
	OVERWORLD_BELOWGROUND=2,
	UNDERWORLD_ABOVEGROUND=3,
	UNDERWORLD_BELOWGROUND=4,
}

enum Id {
	AIR=0,
	GRASS=1,
	DIRT=2,
	STONE=3,
	DEEPGRASS=4,
	DEEPDIRT=5,
	DEEPSTONE=6,
	WOOD=7,
	LEAF=8,
}

const DEFAULT_TEXTURE = Vector2(0, 0)
const IdToTexture = {
	Id.GRASS: Vector2(0, 0),
	Id.DIRT: Vector2(20, 0),
	Id.STONE: Vector2(40, 0),
	Id.DEEPGRASS: Vector2(0, 0),
	Id.DEEPDIRT: Vector2(20, 0),
	Id.DEEPSTONE: Vector2(40, 0),
	Id.WOOD: Vector2(60, 0),
	Id.LEAF: Vector2(60, 20),
}
static func idToTexture(block_id: int) -> Vector2:
	return IdToTexture.get(block_id, DEFAULT_TEXTURE)

static func build(block_position: Vector2, block_id: int) -> Block:
	
	var block = Block.new(block_position, block_id)
	block.position = block_position * Block.SIZE
	
	var texture = BlockTexture.build(block_id)
	block.add_child(texture)
	
	return block


var local_position: Vector2
var id: int

func _init(_local_position: Vector2, _id: int):
	local_position = _local_position
	id = _id
	
	shape = RectangleShape2D.new()
	shape.size = Vector2(Block.SIZE, Block.SIZE)
	
	if id != Id.GRASS:
		rotate(randi() % 4 * (90 * PI / 180))
	
