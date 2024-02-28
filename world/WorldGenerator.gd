class_name WorldGenerator


# Utility classes
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


# Generator classes
class RegionGenerator:
	const HEIGHTMAP_OCTAVES := 5
	const HEIGHTMAP_FREQUENCY := 0.0025
	const HEIGHTMAP_LAYER := 10000
	
	var heightmapNoise: SimplexNoise
	
	func _init(world_seed: int):
		heightmapNoise = SimplexNoise.new(world_seed, HEIGHTMAP_OCTAVES, HEIGHTMAP_FREQUENCY)
	
	const OVERWORLD_SURFACE_POWER = 3
	const OVERWORLD_SURFACE_MULTIPLIER = 300
	const OVERWORLD_SURFACE_OFFSET = 0
	const OVERWORLD_SURFACE_NEIGHBOUR = 2

	const OVERWORLD_LANDSCAPE_POWER = 3
	const OVERWORLD_LANDSCAPE_MULTIPLIER = 150
	const OVERWORLD_LANDSCAPE_OFFSET = 0
	const OVERWORLD_LANDSCAPE_NEIGHBOUR = 2

	const UNDERWORLD_SURFACE_POWER = 1
	const UNDERWORLD_SURFACE_MULTIPLIER = 150
	const UNDERWORLD_SURFACE_OFFSET = 40
	const UNDERWORLD_SURFACE_NEIGHBOUR = 2

	const UNDERWORLD_LANDSCAPE_POWER = 1
	const UNDERWORLD_LANDSCAPE_MULTIPLIER = 20
	const UNDERWORLD_LANDSCAPE_OFFSET = -40
	const UNDERWORLD_LANDSCAPE_NEIGHBOUR = 2
	
	func _calculate_heightmap_value(layer: int, neighbour: int, power: int, multiplier: int, offset: int) -> int:
		var heightmap_layer := heightmapNoise.get_1d_convolution(layer, neighbour)
		heightmap_layer = pow(heightmap_layer, power)
		heightmap_layer *= multiplier
		heightmap_layer += offset
		return floori(heightmap_layer)
	
	func _lerp_heightmap_values(height_value1: int, height_value2: int, layer: int) -> int:
		var lerp_value := (heightmapNoise.get_1d(layer) + 1) / 2
		return floori(lerp(height_value1, height_value2, lerp_value))
	
	func generate_heightmap(region: int) -> Heightmap:
		var heightmap = Heightmap.new(region, [], [], [], [])
		for block in range(Chunk.BLOCK_NUM + 2):
			var location = region * Chunk.BLOCK_NUM + block - 1
			
			var overworld_surface_location := _calculate_heightmap_value(
				location, 
				OVERWORLD_SURFACE_NEIGHBOUR,
				OVERWORLD_SURFACE_POWER,
				OVERWORLD_SURFACE_MULTIPLIER,
				OVERWORLD_SURFACE_OFFSET + World.OVERWORLD)
			heightmap.overworld_surface.append(overworld_surface_location)
			
			var overworld_landscape_location := _calculate_heightmap_value(
				location + HEIGHTMAP_LAYER, 
				OVERWORLD_LANDSCAPE_NEIGHBOUR,
				OVERWORLD_LANDSCAPE_POWER,
				OVERWORLD_LANDSCAPE_MULTIPLIER,
				OVERWORLD_LANDSCAPE_OFFSET + World.OVERWORLD)
			"""overworld_landscape_location = _lerp_heightmap_values(
				overworld_surface_location, 
				overworld_landscape_location,
				location + 2 * HEIGHTMAP_LAYER)"""
			heightmap.overworld_landscape.append(overworld_landscape_location)
			
			var underworld_surface_location := _calculate_heightmap_value(
				location + 3 * HEIGHTMAP_LAYER, 
				UNDERWORLD_SURFACE_NEIGHBOUR,
				UNDERWORLD_SURFACE_POWER,
				UNDERWORLD_SURFACE_MULTIPLIER,
				UNDERWORLD_SURFACE_OFFSET + World.UNDERWORLD)
			heightmap.underworld_surface.append(underworld_surface_location)
			
			var underworld_landscape_location := _calculate_heightmap_value(
				location + 4 * HEIGHTMAP_LAYER, 
				UNDERWORLD_LANDSCAPE_NEIGHBOUR,
				UNDERWORLD_LANDSCAPE_POWER,
				UNDERWORLD_LANDSCAPE_MULTIPLIER,
				UNDERWORLD_LANDSCAPE_OFFSET + World.UNDERWORLD)
			underworld_landscape_location = _lerp_heightmap_values(
				underworld_surface_location, 
				underworld_landscape_location,
				location + 5 * HEIGHTMAP_LAYER)
			heightmap.underworld_landscape.append(underworld_landscape_location)
		
		return heightmap


class ChunkGenerator:
	
	const CAVE_OCTAVES := 4
	const CAVE_FREQUENCY := 0.006
	const LANDSCAPE_OCTAVES := 3
	const LANDSCAPE_FREQUENCY := 0.055
	
	var caveNoise: SimplexNoise
	var landscapeNoise: SimplexNoise
	
	func _init(world_seed: int):
		caveNoise = SimplexNoise.new(world_seed, CAVE_OCTAVES, CAVE_FREQUENCY)
		landscapeNoise = SimplexNoise.new(world_seed, LANDSCAPE_OCTAVES, LANDSCAPE_FREQUENCY)
	
	const OVERWORLD_CAVE_MIN := 0.03
	const OVERWORLD_CAVE_MAX := 0.07
	const OVERWORLD_CAVE_INCREASE := 0.00025
	const OVERWORLD_LANDSCAPE_THRESHOLD := 0.125

	const UNDERWORLD_CAVE_MIN := 0.07
	const UNDERWORLD_CAVE_MAX := 0.14
	const UNDERWORLD_CAVE_INCREASE := 0.0005
	const UNDERWORLD_LANDSCAPE_THRESHOLD := 0.15
	
	func generate_chunk_terrain(chunk_position: Vector2, chunk_heightmap: Heightmap) -> Chunk.Layers:
		var chunk_terrain := Chunk.Layers.new([], [])
	
		for row in range(Chunk.BLOCK_NUM + 2):
			chunk_terrain.foreground.append([])
			chunk_terrain.background.append([])
			for col in range(Chunk.BLOCK_NUM + 2):
				var block_x := floori(chunk_position.x) * Chunk.BLOCK_NUM + col - 1
				var block_y := floori(chunk_position.y) * Chunk.BLOCK_NUM + row - 1
				
				# Is underworld cave
				if block_y >= chunk_heightmap.underworld_surface[col]:
					chunk_terrain.background[row].append(Block.Template.UNDERWORLD_BELOWGROUND)
					
					var underworld_cave := caveNoise.get_2d(block_x, block_y)
					var cave_limit: int = min(chunk_heightmap.underworld_surface[col], chunk_heightmap.underworld_landscape[col])
					var underworld_cave_width := (block_y - cave_limit) * UNDERWORLD_CAVE_INCREASE
					underworld_cave_width = clamp(underworld_cave_width, UNDERWORLD_CAVE_MIN, UNDERWORLD_CAVE_MAX)
					
					var is_cave := underworld_cave <= -underworld_cave_width or underworld_cave >= underworld_cave_width
					if is_cave:
						chunk_terrain.foreground[row].append(Block.Template.UNDERWORLD_BELOWGROUND)
					else:
						chunk_terrain.foreground[row].append(Block.Template.NONE)
				
				# Is underworld
				elif block_y >= chunk_heightmap.underworld_landscape[col]:
					chunk_terrain.background[row].append(Block.Template.UNDERWORLD_ABOVEGROUND)
					
					var undeworld_landscape := landscapeNoise.get_2d(block_x, block_y)
						
					if undeworld_landscape > UNDERWORLD_LANDSCAPE_THRESHOLD:
						chunk_terrain.foreground[row].append(Block.Template.UNDERWORLD_ABOVEGROUND)
					else:
						chunk_terrain.foreground[row].append(Block.Template.NONE)
				
				# Is overworld cave
				elif block_y >= chunk_heightmap.overworld_surface[col]:
					chunk_terrain.background[row].append(Block.Template.OVERWORLD_BELOWGROUND)
					
					var overworld_cave := caveNoise.get_2d(block_x, block_y)
					var overworld_cave_width := (block_y - chunk_heightmap.overworld_surface[col]) * OVERWORLD_CAVE_INCREASE
					overworld_cave_width = clamp(overworld_cave_width, OVERWORLD_CAVE_MIN, OVERWORLD_CAVE_MAX)
					
					var is_cave := overworld_cave <= -overworld_cave_width or overworld_cave >= overworld_cave_width
					if is_cave:
						chunk_terrain.foreground[row].append(Block.Template.OVERWORLD_BELOWGROUND)
					else:
						chunk_terrain.foreground[row].append(Block.Template.NONE)
				
				# Is overworld
				elif block_y >= chunk_heightmap.overworld_landscape[col]:
					chunk_terrain.background[row].append(Block.Template.OVERWORLD_ABOVEGROUND)
					
					var overworld_landscape := landscapeNoise.get_2d(block_x, block_y)
						
					if overworld_landscape > OVERWORLD_LANDSCAPE_THRESHOLD:
						chunk_terrain.foreground[row].append(Block.Template.OVERWORLD_ABOVEGROUND)
					else:
						chunk_terrain.foreground[row].append(Block.Template.NONE)
				
				# Is empty
				else:
					chunk_terrain.background[row].append(Block.Template.NONE)
					chunk_terrain.foreground[row].append(Block.Template.NONE)
		
		return chunk_terrain
	
	const OVERWORLD_SURFACE_DEPTH := 5
	const UNDERWORLD_SURFACE_DEPTH := 15
	
	func generate_chunk_blocks(chunk_terrain: Chunk.Layers, chunk_position: Vector2, chunk_heightmap: Heightmap) -> Chunk.Layers:
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
				
				var foreground_block_template: int = chunk_terrain.foreground[block_row][block_col]
				var background_block_template: int = chunk_terrain.background[block_row][block_col]
				
				var exact_overworld_surface := chunk_heightmap.overworld_surface[block_col]
				var exact_underworld_surface := chunk_heightmap.underworld_surface[block_col]
				
				# Handles no foreground
				if foreground_block_template == Block.Template.NONE:
					chunk_blocks.foreground[row].append(Block.Id.AIR)
				
				# Handles above ground overworld foreground
				elif foreground_block_template == Block.Template.OVERWORLD_ABOVEGROUND:
					var is_above_empty: bool = chunk_terrain.foreground[block_row - 1][block_col] == Block.Template.NONE
					var is_on_surface := block_y <= exact_overworld_surface
					
					if is_above_empty and is_on_surface:
						chunk_blocks.foreground[row].append(Block.Id.GRASS)
					else:
						chunk_blocks.foreground[row].append(Block.Id.DIRT)
				
				# Handles below ground overworld foreground
				elif foreground_block_template == Block.Template.OVERWORLD_BELOWGROUND:
					var is_above_empty: bool = chunk_terrain.foreground[block_row - 1][block_col] == Block.Template.NONE
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
					var is_above_empty: bool = chunk_terrain.foreground[block_row - 1][block_col] == Block.Template.NONE
					var is_on_surface := block_y <= exact_underworld_surface
					
					if is_above_empty and is_on_surface:
						chunk_blocks.foreground[row].append(Block.Id.DEEPGRASS)
					else:
						chunk_blocks.foreground[row].append(Block.Id.DEEPDIRT)
				
				# Handles below ground underworld foreground
				elif foreground_block_template == Block.Template.UNDERWORLD_BELOWGROUND:
					var is_above_empty: bool = chunk_terrain.foreground[block_row - 1][block_col] == Block.Template.NONE
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
					var is_above_empty: bool = chunk_terrain.background[block_row - 1][block_col] == Block.Template.NONE
					var is_on_surface := block_y <= exact_overworld_surface
					
					if is_above_empty and is_on_surface:
						chunk_blocks.background[row].append(Block.Id.GRASS)
					else:
						chunk_blocks.background[row].append(Block.Id.DIRT)
				
				# Handles below ground overworld background
				elif background_block_template == Block.Template.OVERWORLD_BELOWGROUND:
					var is_above_empty: bool = chunk_terrain.background[block_row - 1][block_col] == Block.Template.NONE
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
					var is_above_empty: bool = chunk_terrain.background[block_row - 1][block_col] == Block.Template.NONE
					var is_on_surface := block_y <= exact_underworld_surface
					
					if is_above_empty and is_on_surface:
						chunk_blocks.background[row].append(Block.Id.DEEPGRASS)
					else:
						chunk_blocks.background[row].append(Block.Id.DEEPDIRT)
				
				# Handles below ground underworld background
				elif background_block_template == Block.Template.UNDERWORLD_BELOWGROUND:
					var is_above_empty: bool = chunk_terrain.background[block_row - 1][block_col] == Block.Template.NONE
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
	
	func generate_chunk(chunk_position: Vector2, chunk_heightmap: Heightmap) -> Chunk:
		var chunk_terrain := generate_chunk_terrain(chunk_position, chunk_heightmap)
		var chunk_blocks := generate_chunk_blocks(chunk_terrain, chunk_position, chunk_heightmap)
		var chunk := Chunk.new(chunk_position, chunk_blocks)
		
		return chunk


class StructureGenerator:
	var TreeNoise: SimplexNoise
	
	func _init(world_seed: int):
		TreeNoise = SimplexNoise.new(world_seed, 3, 0.01)
	
	func generate_trees(heightmap: Heightmap) -> Array[Structure]:
		var heightmap_pos := 3
		if heightmap.overworld_surface[heightmap_pos] < heightmap.overworld_landscape[heightmap_pos]:
			if TreeNoise.get_1d(heightmap.overworld_surface[heightmap_pos]) >= -0.25:
				var tree_x = heightmap.region * Chunk.BLOCK_NUM
				var tree_y = heightmap.overworld_surface[heightmap_pos] - 5
				var tree = Structure.new(Vector2(tree_x, tree_y), Vector2(5, 5), 
					[
						[Block.Id.AIR, Block.Id.LEAF, Block.Id.LEAF, Block.Id.LEAF, Block.Id.AIR],
						[Block.Id.LEAF, Block.Id.LEAF, Block.Id.WOOD, Block.Id.LEAF, Block.Id.LEAF],
						[Block.Id.LEAF, Block.Id.LEAF, Block.Id.WOOD, Block.Id.LEAF, Block.Id.LEAF],
						[Block.Id.AIR, Block.Id.LEAF, Block.Id.WOOD, Block.Id.LEAF, Block.Id.AIR],
						[Block.Id.AIR, Block.Id.AIR, Block.Id.WOOD, Block.Id.AIR, Block.Id.AIR],
						[Block.Id.AIR, Block.Id.AIR, Block.Id.WOOD, Block.Id.AIR, Block.Id.AIR],
					], 
					[
						[Block.Id.AIR, Block.Id.AIR, Block.Id.AIR, Block.Id.AIR, Block.Id.AIR],
						[Block.Id.AIR, Block.Id.AIR, Block.Id.AIR, Block.Id.AIR, Block.Id.AIR],
						[Block.Id.AIR, Block.Id.AIR, Block.Id.AIR, Block.Id.AIR, Block.Id.AIR],
						[Block.Id.AIR, Block.Id.AIR, Block.Id.AIR, Block.Id.AIR, Block.Id.AIR],
						[Block.Id.AIR, Block.Id.AIR, Block.Id.AIR, Block.Id.AIR, Block.Id.AIR],
						[Block.Id.AIR, Block.Id.AIR, Block.Id.AIR, Block.Id.AIR, Block.Id.AIR],
					])
				return [tree]
			else:
				return []
		else:
			return []
	
	func generate_structures(region_heightmap: Heightmap) -> Dictionary:
	
		var structures: Array[Structure] = []
		
		var trees = generate_trees(region_heightmap)
		structures.append_array(trees)
		
		var chunk_structures: Dictionary = {}
		
		for structure in structures:
			for structure_block_y in range(structure.size.y):
				for structure_block_x in range(structure.size.x):
					var structure_position = Vector2(structure.position.x + structure_block_x, structure.position.y + structure_block_y)
					var chunk_position = floor(structure_position / Chunk.BLOCK_NUM)
					var chunk_block = structure_position - chunk_position * Chunk.BLOCK_NUM
					
					if not chunk_structures.has(chunk_position):
						chunk_structures[chunk_position] = Chunk.Layers.init_empty()
					
					chunk_structures[chunk_position].foreground[chunk_block.y][chunk_block.x] = structure.foreground[structure_block_y][structure_block_x]
					chunk_structures[chunk_position].background[chunk_block.y][chunk_block.x] = structure.background[structure_block_y][structure_block_x]
		
		return chunk_structures
