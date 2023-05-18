extends Sprite2D
class_name BlockTexture


static func build(block_id: int) -> BlockTexture:
	
	var texture_pos = Block.IdToTexture.get(block_id, Block.DEFAULT_TEXTURE)
	var block_texture = BlockTexture.new(texture_pos)
	
	return block_texture


var textureAtlas = preload("res://world/chunk/block/texture/block_atlas.tres")

var texture_position: Vector2

func _init(_texture_position: Vector2):
	texture_position = _texture_position

func _ready():
	texture = textureAtlas.duplicate()
	texture.region = Rect2(texture_position.x, texture_position.y, Block.SIZE, Block.SIZE)
