class_name ChunkGeneratorr


# OpenSimplexNoise wrapper for extra functionality
class SimplexNoise:
	var noise: FastNoiseLite
	
	func _init(noise_seed: int, octaves: int, frequency: float):
		noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise.seed = noise_seed
		noise.fractal_octaves = octaves
		noise.frequency = frequency
	
	func get_1d(x: float) -> float:
		return noise.get_noise_1d(x)
	
	func get_1d_convolution(x: float, width: int) -> float:
		var value = 0
		
		for w in range(-width, width + 1):
			value += get_1d(x + w)
		value /= width*2 + 1
		
		return value
	
	func get_2d(x: float, y: float) -> float:
		return noise.get_noise_2d(x, y)


# Container for the different heightmaps
class Heightmap:
	var region: float
	var overworld_surface: Array[int]
	var overworld_landscape: Array[int]
	var underworld_surface: Array[int]
	var underworld_landscape: Array[int]
	
	func _init(_region: float, _overworld_surface: Array[int], _overworld_landscape: Array[int], _underworld_surface: Array[int], _underworld_landscape: Array[int]):
		region = _region 
		overworld_surface = _overworld_surface
		overworld_landscape = _overworld_landscape
		underworld_surface = _underworld_surface
		underworld_landscape = _underworld_landscape


class Structure:
	var position: Vector2
	var size: Vector2
	var foreground: Array[Array]
	var background: Array[Array]
	
	func _init(_position: Vector2, _size: Vector2, _foreground: Array[Array], _background: Array[Array]):
		position = _position
		size = _size
		foreground = _foreground
		background = _background


class RegionGenerator:
	pass


class TerrainGenerator:
	pass


class StructureGenerator:
	pass


# Noise function parameters
const LANDSCAPE_OCTAVES := 2
const LANDSCAPE_FREQUENCY := 0.05

const TERRAIN_OCTAVES := 6
const TERRAIN_FREQUENCY := 0.005

const CAVE_OCTAVES := 5
const CAVE_FREQUENCY := 0.005

# Creates a seperate layer for 1d noise functions
const TERRAIN_LAYER := 10000

# Noise functions
var landscapeNoise: SimplexNoise
var terrainNoise: SimplexNoise
var caveNoise: SimplexNoise

func _init(world_seed: int):
	landscapeNoise = SimplexNoise.new(world_seed, LANDSCAPE_OCTAVES, LANDSCAPE_FREQUENCY)
	terrainNoise = SimplexNoise.new(world_seed, TERRAIN_OCTAVES, TERRAIN_FREQUENCY)
	caveNoise = SimplexNoise.new(world_seed, CAVE_OCTAVES, CAVE_FREQUENCY)

# Height map generation variables
const OVERWORLD_SURFACE_POWER = 3
const OVERWORLD_SURFACE_MULTIPLIER = 200
const OVERWORLD_SURFACE_OFFSET = 0

const OVERWORLD_LANDSCAPE_POWER = 3
const OVERWORLD_LANDSCAPE_MULTIPLIER = 0
const OVERWORLD_LANDSCAPE_OFFSET = 200

const UNDERWORLD_SURFACE_POWER = 1
const UNDERWORLD_SURFACE_MULTIPLIER = 150
const UNDERWORLD_SURFACE_OFFSET = 40

const UNDERWORLD_LANDSCAPE_POWER = 1
const UNDERWORLD_LANDSCAPE_MULTIPLIER = 20
const UNDERWORLD_LANDSCAPE_OFFSET = -40

# Chunk template generation variables
const OVERWORLD_CAVE_MIN = 0.03
const OVERWORLD_CAVE_MAX = 0.08
const OVERWORLD_CAVE_INCREASE = 0.0005
const OVERWORLD_LANDSCAPE_THRESHOLD = 0.15

const UNDERWORLD_CAVE_MIN = 0.08
const UNDERWORLD_CAVE_MAX = 0.13
const UNDERWORLD_CAVE_INCREASE = 0.001
const UNDERWORLD_LANDSCAPE_THRESHOLD = 0.15

# Chunk block generation variables
const OVERWORLD_SURFACE_DEPTH = 5
const UNDERWORLD_SURFACE_DEPTH = 15

# Generates a height map for every horizontal point in a given chunk plus an aditional value on either side
func generate_heightmap(region: int) -> Heightmap:
	
	var heightmap = Heightmap.new(region, [], [], [], [])
	for block in range(Chunk.BLOCK_NUM + 2):
		var location = region * Chunk.BLOCK_NUM + block - 1
		
		var overworld_surface_location := terrainNoise.get_1d_convolution(location, 2)
		overworld_surface_location = pow(overworld_surface_location, OVERWORLD_SURFACE_POWER)
		overworld_surface_location *= OVERWORLD_SURFACE_MULTIPLIER
		overworld_surface_location += OVERWORLD_SURFACE_OFFSET
		overworld_surface_location += World.OVERWORLD
		heightmap.overworld_surface.append(floori(overworld_surface_location))
		
		var overworld_landscape_location := terrainNoise.get_1d_convolution(location + TERRAIN_LAYER, 2)
		overworld_landscape_location = pow(overworld_landscape_location, OVERWORLD_LANDSCAPE_POWER)
		overworld_landscape_location *= OVERWORLD_LANDSCAPE_MULTIPLIER
		overworld_landscape_location += OVERWORLD_LANDSCAPE_OFFSET
		overworld_landscape_location += World.OVERWORLD
		var overworld_landscape_lerp := (terrainNoise.get_1d(location + 0.5 * TERRAIN_LAYER) + 1) / 2
		overworld_landscape_location = lerp(overworld_surface_location, overworld_landscape_location, overworld_landscape_lerp)
		heightmap.overworld_landscape.append(floori(overworld_landscape_location))
		
		var underworld_surface_location := terrainNoise.get_1d_convolution(location + 2 * TERRAIN_LAYER, 2)
		underworld_surface_location = pow(underworld_surface_location, UNDERWORLD_SURFACE_POWER)
		underworld_surface_location *= UNDERWORLD_SURFACE_MULTIPLIER
		underworld_surface_location += UNDERWORLD_SURFACE_OFFSET
		underworld_surface_location += World.UNDERWORLD
		heightmap.underworld_surface.append(floori(underworld_surface_location))
		
		var underworld_landscape_location := terrainNoise.get_1d_convolution(location + 3 * TERRAIN_LAYER, 2)
		underworld_landscape_location = pow(underworld_landscape_location, UNDERWORLD_LANDSCAPE_POWER)
		underworld_landscape_location *= UNDERWORLD_LANDSCAPE_MULTIPLIER
		underworld_landscape_location += UNDERWORLD_LANDSCAPE_OFFSET
		underworld_landscape_location += World.UNDERWORLD
		var underworld_landscape_lerp := (terrainNoise.get_1d(location + 2.5 * TERRAIN_LAYER) + 1) / 2
		underworld_landscape_location = lerp(underworld_surface_location, underworld_landscape_location, underworld_landscape_lerp)
		heightmap.underworld_landscape.append(floori(underworld_landscape_location))
	
	return heightmap

# Generates a chunk template, describing what type of enviorment the blocks belong to
func generate_chunk_template(chunk_position: Vector2, chunk_heightmap: Heightmap) -> Chunk.Layers:
	
	var chunk_template := Chunk.Layers.new([], [])
	
	for row in range(Chunk.BLOCK_NUM + 2):
		chunk_template.foreground.append([])
		chunk_template.background.append([])
		for col in range(Chunk.BLOCK_NUM + 2):
			var block_x := floori(chunk_position.x) * Chunk.BLOCK_NUM + col - 1
			var block_y := floori(chunk_position.y) * Chunk.BLOCK_NUM + row - 1
			
			# Is underworld cave
			if block_y >= chunk_heightmap.underworld_surface[col]:
				chunk_template.background[row].append(Block.Template.UNDERWORLD_BELOWGROUND)
				
				var underworld_cave := caveNoise.get_2d(block_x, block_y)
				var underworld_cave_width := (block_y - chunk_heightmap.underworld_surface[col]) * UNDERWORLD_CAVE_INCREASE
				underworld_cave_width = clamp(underworld_cave_width, UNDERWORLD_CAVE_MIN, UNDERWORLD_CAVE_MAX)
				
				var is_cave := underworld_cave <= -underworld_cave_width or underworld_cave >= underworld_cave_width
				if is_cave:
					chunk_template.foreground[row].append(Block.Template.UNDERWORLD_BELOWGROUND)
				else:
					chunk_template.foreground[row].append(Block.Template.NONE)
			
			# Is underworld
			elif block_y >= chunk_heightmap.underworld_landscape[col]:
				chunk_template.background[row].append(Block.Template.UNDERWORLD_ABOVEGROUND)
				
				var undeworld_landscape := landscapeNoise.get_2d(block_x, block_y)
					
				if undeworld_landscape > UNDERWORLD_LANDSCAPE_THRESHOLD:
					chunk_template.foreground[row].append(Block.Template.UNDERWORLD_ABOVEGROUND)
				else:
					chunk_template.foreground[row].append(Block.Template.NONE)
			
			# Is overworld cave
			elif block_y >= chunk_heightmap.overworld_surface[col]:
				chunk_template.background[row].append(Block.Template.OVERWORLD_BELOWGROUND)
				
				var overworld_cave := caveNoise.get_2d(block_x, block_y)
				var overworld_cave_width := (block_y - chunk_heightmap.overworld_surface[col]) * OVERWORLD_CAVE_INCREASE
				overworld_cave_width = clamp(overworld_cave_width, OVERWORLD_CAVE_MIN, OVERWORLD_CAVE_MAX)
				
				var is_cave := overworld_cave <= -overworld_cave_width or overworld_cave >= overworld_cave_width
				if is_cave:
					chunk_template.foreground[row].append(Block.Template.OVERWORLD_BELOWGROUND)
				else:
					chunk_template.foreground[row].append(Block.Template.NONE)
			
			# Is overworld
			elif block_y >= chunk_heightmap.overworld_landscape[col]:
				chunk_template.background[row].append(Block.Template.OVERWORLD_ABOVEGROUND)
				
				var overworld_landscape := landscapeNoise.get_2d(block_x, block_y)
					
				if overworld_landscape > OVERWORLD_LANDSCAPE_THRESHOLD:
					chunk_template.foreground[row].append(Block.Template.OVERWORLD_ABOVEGROUND)
				else:
					chunk_template.foreground[row].append(Block.Template.NONE)
			
			# Is empty
			else:
				chunk_template.background[row].append(Block.Template.NONE)
				chunk_template.foreground[row].append(Block.Template.NONE)
	
	return chunk_template

# Converts the chunk templates to individual blocks
func generate_chunk_blocks(chunk_template: Chunk.Layers, chunk_position: Vector2, chunk_heightmap: Heightmap) -> Chunk.Layers:
	
	var chunk_blocks := Chunk.Layers.new([], [])
	
	for row in range(Chunk.BLOCK_NUM):
		chunk_blocks.foreground.append([])
		chunk_blocks.background.append([])
		for col in range(Chunk.BLOCK_NUM):
			# var block_x: int = chunk_position.x * Chunk.BLOCK_NUM + col
			var block_y := floori(chunk_position.y) * Chunk.BLOCK_NUM + row
			
			# Indecies ignoring block outside of chunk
			var block_row := row + 1
			var block_col := col + 1
			
			var foreground_block_template: int = chunk_template.foreground[block_row][block_col]
			var background_block_template: int = chunk_template.background[block_row][block_col]
			
			var exact_overworld_surface := chunk_heightmap.overworld_surface[block_col]
			var exact_underworld_surface := chunk_heightmap.underworld_surface[block_col]
			
			# Handles no foreground
			if foreground_block_template == Block.Template.NONE:
				chunk_blocks.foreground[row].append(Block.Id.AIR)
			
			# Handles above ground overworld foreground
			elif foreground_block_template == Block.Template.OVERWORLD_ABOVEGROUND:
				var is_above_empty: bool = chunk_template.foreground[block_row - 1][block_col] == Block.Template.NONE
				var is_on_surface := block_y <= exact_overworld_surface
				
				if is_above_empty and is_on_surface:
					chunk_blocks.foreground[row].append(Block.Id.GRASS)
				else:
					chunk_blocks.foreground[row].append(Block.Id.DIRT)
			
			# Handles below ground overworld foreground
			elif foreground_block_template == Block.Template.OVERWORLD_BELOWGROUND:
				var is_above_empty: bool = chunk_template.foreground[block_row - 1][block_col] == Block.Template.NONE
				var is_on_surface := block_y <= exact_overworld_surface
				var is_part_of_surface := block_y <= exact_overworld_surface + OVERWORLD_SURFACE_DEPTH
				
				if is_part_of_surface:
					if is_above_empty and is_on_surface:
						chunk_blocks.foreground[row].append(Block.Id.GRASS)
					else:
						chunk_blocks.foreground[row].append(Block.Id.DIRT)
				else:
					chunk_blocks.foreground[row].append(Block.Id.STONE)
			
			# Handles above ground underworld foreground
			elif foreground_block_template == Block.Template.UNDERWORLD_ABOVEGROUND:
				var is_above_empty: bool = chunk_template.foreground[block_row - 1][block_col] == Block.Template.NONE
				var is_on_surface := block_y <= exact_underworld_surface
				
				if is_above_empty and is_on_surface:
					chunk_blocks.foreground[row].append(Block.Id.DEEPGRASS)
				else:
					chunk_blocks.foreground[row].append(Block.Id.DEEPDIRT)
			
			# Handles below ground underworld foreground
			elif foreground_block_template == Block.Template.UNDERWORLD_BELOWGROUND:
				var is_above_empty: bool = chunk_template.foreground[block_row - 1][block_col] == Block.Template.NONE
				var is_on_surface := block_y <= exact_underworld_surface
				var is_part_of_surface := block_y <= exact_underworld_surface + UNDERWORLD_SURFACE_DEPTH
				
				if is_part_of_surface:
					if is_above_empty and is_on_surface:
						chunk_blocks.foreground[row].append(Block.Id.DEEPGRASS)
					else:
						chunk_blocks.foreground[row].append(Block.Id.DEEPDIRT)
				else:
					chunk_blocks.foreground[row].append(Block.Id.DEEPSTONE)
			
			# Handles no match case (Shouldn't happen)
			else:
				chunk_blocks.foreground[row].append(Block.Id.AIR)
			
			# Handles no background
			if background_block_template == Block.Template.NONE:
				chunk_blocks.background[row].append(Block.Id.AIR)
			
			# Handles above ground overworld background
			elif background_block_template == Block.Template.OVERWORLD_ABOVEGROUND:
				var is_above_empty: bool = chunk_template.background[block_row - 1][block_col] == Block.Template.NONE
				var is_on_surface := block_y <= exact_overworld_surface
				
				if is_above_empty and is_on_surface:
					chunk_blocks.background[row].append(Block.Id.GRASS)
				else:
					chunk_blocks.background[row].append(Block.Id.DIRT)
			
			# Handles below ground overworld background
			elif background_block_template == Block.Template.OVERWORLD_BELOWGROUND:
				var is_above_empty: bool = chunk_template.background[block_row - 1][block_col] == Block.Template.NONE
				var is_on_surface := block_y <= exact_overworld_surface
				var is_part_of_surface := block_y <= exact_overworld_surface + OVERWORLD_SURFACE_DEPTH
				
				if is_part_of_surface:
					if is_above_empty and is_on_surface:
						chunk_blocks.background[row].append(Block.Id.GRASS)
					else:
						chunk_blocks.background[row].append(Block.Id.DIRT)
				else:
					chunk_blocks.background[row].append(Block.Id.STONE)
			
			# Handles above ground underworld background
			elif background_block_template == Block.Template.UNDERWORLD_ABOVEGROUND:
				var is_above_empty: bool = chunk_template.background[block_row - 1][block_col] == Block.Template.NONE
				var is_on_surface := block_y <= exact_underworld_surface
				
				if is_above_empty and is_on_surface:
					chunk_blocks.background[row].append(Block.Id.DEEPGRASS)
				else:
					chunk_blocks.background[row].append(Block.Id.DEEPDIRT)
			
			# Handles below ground underworld background
			elif background_block_template == Block.Template.UNDERWORLD_BELOWGROUND:
				var is_above_empty: bool = chunk_template.background[block_row - 1][block_col] == Block.Template.NONE
				var is_on_surface := block_y <= exact_underworld_surface
				var is_part_of_surface := block_y <= exact_underworld_surface + UNDERWORLD_SURFACE_DEPTH
				
				if is_part_of_surface:
					if is_above_empty and is_on_surface:
						chunk_blocks.background[row].append(Block.Id.DEEPGRASS)
					else:
						chunk_blocks.background[row].append(Block.Id.DEEPDIRT)
				else:
					chunk_blocks.background[row].append(Block.Id.DEEPSTONE)
			
			# Handles no match case (Shouldn't happen)
			else:
				chunk_blocks.background[row].append(Block.Id.AIR)
	
	return chunk_blocks

func generate_structures(region_heightmap: Heightmap):
	
	var structures: Array[Structure] = []
	
	if region_heightmap.overworld_surface[1] < region_heightmap.overworld_landscape[1]:
		var tree_x = region_heightmap.region * Chunk.BLOCK_NUM
		var tree_y = region_heightmap.overworld_surface[1] - 3
		var new_tree = Structure.new(Vector2(tree_x, tree_y), Vector2(1, 3), [[Block.Id.WOOD], [Block.Id.WOOD], [Block.Id.WOOD]], [[Block.Id.AIR], [Block.Id.AIR], [Block.Id.AIR]])
		structures.append(new_tree)
	
	var chunks_with_structures = {}
	
	for structure in structures:
		for structure_block_y in range(structure.size.y):
			for structure_block_x in range(structure.size.x):
				var structure_position = Vector2(structure.position.x + structure_block_x, structure.position.y + structure_block_y)
				var chunk_position = floor(structure_position / Chunk.BLOCK_NUM)
				
				var chunk_block = structure_position - chunk_position * Chunk.BLOCK_NUM
				
				if not chunks_with_structures.has(chunk_position):
					chunks_with_structures[chunk_position] = Chunk.Layers.init_empty()
				
				chunks_with_structures[chunk_position].foreground[chunk_block.y][chunk_block.x] = structure.foreground[structure_block_y][structure_block_x]
				chunks_with_structures[chunk_position].background[chunk_block.y][chunk_block.x] = structure.background[structure_block_y][structure_block_x]
	
	for chunk_strucutre_position in chunks_with_structures.keys():
		WorldFiles.save_structure('Hello world', chunk_strucutre_position, chunks_with_structures[chunk_strucutre_position])

# Generates the specified chunk
func generate_chunk(chunk_position: Vector2, chunk_heightmap: Heightmap) -> Chunk:
	
	var chunk_template := generate_chunk_template(chunk_position, chunk_heightmap)
	var chunk_blocks := generate_chunk_blocks(chunk_template, chunk_position, chunk_heightmap)
	var chunk = Chunk.new(chunk_position, chunk_blocks)
	
	return chunk
