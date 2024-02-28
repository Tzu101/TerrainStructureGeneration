class_name WorldFiles


const REGIONS_FOLDER: String = 'regions'
const CHUNKS_FOLDER: String = 'chunks'

const HEIGHTMAP_FILE = 'heightmap'
const STRUCTURES_FILE = 'structures'
const BLOCKS_FILE = 'blocks'
const BINARY_EXTENSION: String = 'bin'

static func get_world_folder(world_name: String) -> String:
	return '%s/%s' % [GameFiles.WORLDS_FOLDER, world_name]

static func get_regions_folder(world_name: String) -> String:
	return '%s/%s' % [get_world_folder(world_name), REGIONS_FOLDER]

static func get_region_folder(world_name: String, region: float) -> String:
	return '%s/%d' % [get_regions_folder(world_name), region]

static func get_chunk_folder(world_name: String, chunk_position: Vector2) -> String:
	return '%s/%s/%d %d' % [get_region_folder(world_name, chunk_position.x), CHUNKS_FOLDER, chunk_position.x, chunk_position.y]

static func init_world_files(world_name: String):
	FileManager.make_folder(get_world_folder(world_name))
	FileManager.make_folder(get_regions_folder((world_name)))

static func init_region_folder(world_name: String, region: float):
	var region_folder := get_region_folder(world_name, region)
	FileManager.make_folder(region_folder)
	var chunks_folder = '%s/%s' % [region_folder, CHUNKS_FOLDER]
	FileManager.make_folder(chunks_folder)

static func init_chunk_folder(world_name: String, chunk_position: Vector2):
	var chunk_folder := get_chunk_folder(world_name, chunk_position)
	FileManager.make_folder(chunk_folder)

static func save_heightmap(world_name: String, heightmap: WorldGenerator.Heightmap) -> void:
	var region_folder := get_region_folder(world_name, heightmap.region)
	var heightmap_file := '%s.%s' % [HEIGHTMAP_FILE, BINARY_EXTENSION]
	var heightmap_path := '%s/%s' % [region_folder, heightmap_file]
	
	var heightmap_data: Array[int] = []
	for col in range(Chunk.BLOCK_NUM + 2):
		heightmap_data.append(heightmap.overworld_landscape[col])
		heightmap_data.append(heightmap.overworld_surface[col])
		heightmap_data.append(heightmap.underworld_landscape[col])
		heightmap_data.append(heightmap.underworld_surface[col])
	
	FileManager.save_64_bit(heightmap_path, heightmap_data)

static func load_heightmap(world_name: String, region: float) -> WorldGenerator.Heightmap:
	var region_folder := get_region_folder(world_name, region)
	var heightmap_file := '%s.%s' % [HEIGHTMAP_FILE, BINARY_EXTENSION]
	var heightmap_path := '%s/%s' % [region_folder, heightmap_file]
	
	var heightmap_data := FileManager.load_64_bit(heightmap_path)
	
	if heightmap_data.size() <= 0:
		return null
	
	var heightmap := WorldGenerator.Heightmap.new(region, [], [], [], [])
	for col in range(Chunk.BLOCK_NUM + 2):
		var index  = 4 * col
		heightmap.overworld_landscape.append(heightmap_data[index])
		heightmap.overworld_surface.append(heightmap_data[index + 1])
		heightmap.underworld_landscape.append(heightmap_data[index + 2])
		heightmap.underworld_surface.append(heightmap_data[index + 3])
	
	return heightmap

static func _save_chunk_layers(file_path: String, chunk_layers: Chunk.Layers):
	
	# TEMP fix, TODO find cause
	if not chunk_layers:
		return
	
	var file_data: Array[int] = []
	
	for row in range(Chunk.BLOCK_NUM):
		for col in range(Chunk.BLOCK_NUM):
			file_data.append(chunk_layers.foreground[row][col])
			file_data.append(chunk_layers.background[row][col])
	
	FileManager.save_16_bit(file_path, file_data)

static func save_chunk(world_name: String, chunk: Chunk):
	if chunk == null:
		return
	
	var chunk_folder := get_chunk_folder(world_name, chunk.local_position)
	var blocks_file := '%s.%s' % [BLOCKS_FILE, BINARY_EXTENSION]
	var blocks_path := '%s/%s' % [chunk_folder, blocks_file]
	
	_save_chunk_layers(blocks_path, chunk.layers)

static func save_structure(world_name: String, structure_position: Vector2, structure_layers: Chunk.Layers):
	var current_structure_layers := load_structure(world_name, structure_position)
	if current_structure_layers != null:
		for row in range(Chunk.BLOCK_NUM):
			for col in range(Chunk.BLOCK_NUM):
				if structure_layers.foreground[row][col] != Block.Id.AIR:
					current_structure_layers.foreground[row][col] = structure_layers.foreground[row][col]
				if structure_layers.background[row][col] != Block.Id.AIR:
					current_structure_layers.background[row][col] = structure_layers.background[row][col]
	else:
		current_structure_layers = structure_layers
	
	var chunk_folder := get_chunk_folder(world_name, structure_position)
	var structure_file := '%s.%s' % [STRUCTURES_FILE, BINARY_EXTENSION]
	var structure_path := '%s/%s' % [chunk_folder, structure_file]
	
	_save_chunk_layers(structure_path, current_structure_layers)

static func _load_chunk_layers(file_path: String) -> Chunk.Layers:
	var file_data := FileManager.load_16_bit(file_path)
	if file_data.size() <= 0:
		return null
	
	var chunk_layers := Chunk.Layers.new([], [])
	
	for row in range(Chunk.BLOCK_NUM):
		chunk_layers.foreground.append([])
		chunk_layers.background.append([])
		for col in range(Chunk.BLOCK_NUM):
			var index = 2 * (Chunk.BLOCK_NUM * row + col)
			chunk_layers.foreground[row].append(file_data[index])
			chunk_layers.background[row].append(file_data[index + 1])
	
	return chunk_layers

static func load_chunk(world_name: String, chunk_position: Vector2) -> Chunk:
	var chunk_folder := get_chunk_folder(world_name, chunk_position)
	var blocks_file := '%s.%s' % [BLOCKS_FILE, BINARY_EXTENSION]
	var blocks_path := '%s/%s' % [chunk_folder, blocks_file]
	
	var blocks_data := _load_chunk_layers(blocks_path)
	if blocks_data == null:
		return null
	
	return Chunk.new(chunk_position, blocks_data)

static func load_structure(world_name: String, chunk_position: Vector2) -> Chunk.Layers:
	var chunk_folder := get_chunk_folder(world_name, chunk_position)
	var structure_file := '%s.%s' % [STRUCTURES_FILE, BINARY_EXTENSION]
	var structure_path := '%s/%s' % [chunk_folder, structure_file]
	
	var structure_layers = _load_chunk_layers(structure_path)
	FileManager.delete_permanently(structure_path)
	return structure_layers
