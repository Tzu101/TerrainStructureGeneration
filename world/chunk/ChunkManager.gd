class_name ChunkManager


class MultiThread:
	var is_running: bool
	var mutex: Mutex
	var thread: Thread
	var semaphore: Semaphore
	
	func _init():
		is_running = true
		mutex = Mutex.new()
		thread = Thread.new()
		semaphore = Semaphore.new()
		
		thread.start(_excecution_thread)
	
	func _excecution_thread():
		while is_running:
			semaphore.wait()
	
	func finish():
		mutex.lock()
		is_running = false
		mutex.unlock()
		
		semaphore.post()
		thread.wait_to_finish()


class RegionLoader extends MultiThread:
	var region_queue: Array[float]
	var is_loading: bool
	var loading_region: float
	
	var heightmaps: Dictionary
	
	func _init(_heightmaps: Dictionary):
		super()
		
		heightmaps = _heightmaps
		
		region_queue = []
		is_loading = false
		loading_region = 0
	
	func _excecution_thread():
		print('Extended')


class ChunkLoader extends MultiThread:
	var heightmaps: Dictionary
	
	func _init():
		super()
	
	func _excecution_thread():
		print('Extended')


class ChunkSaver extends MultiThread:
	var heightmaps: Dictionary
	
	func _init():
		super()
	
	func _excecution_thread():
		print('Extended')


var chunks: Dictionary = {}
var adjacent_chunk_positions: Array[Vector2]

var is_manager_running: bool = true
var heightmap_store: Dictionary = {}

var load_chunk_queue: Array[Vector2] = []
# No type because Vector2 cannot be null
var loading_chunk = null
var loaded_chunk: Chunk = null

var mutexGen: Mutex = Mutex.new()
var threadGen: Thread = Thread.new()
var semaphoreGen: Semaphore = Semaphore.new()

var save_chunk_queue: Array[Chunk] = []
var saving_chunk: Chunk = null

var mutexSave: Mutex = Mutex.new()
var threadSave: Thread = Thread.new()
var semaphoreSave: Semaphore = Semaphore.new()

var world: Node2D
var world_seed: int
var world_name: String

var render_distance: int
var load_distance: int
var preload_distance: int

var chunkGenerator: ChunkGenerator

func _init(_world: Node2D, _world_seed: int, _world_name: String, _render_distance = 2):
	world = _world
	world_seed = _world_seed
	world_name = _world_name
	
	render_distance = _render_distance
	load_distance = render_distance + 2
	preload_distance = load_distance + 3
	
	chunkGenerator = ChunkGenerator.new(world_seed)
	
	# Calculate adjacent chunks with anon function
	adjacent_chunk_positions = (
	func () -> Array[Vector2]:
		var adjacent_positions: Array[Vector2] = []
		
		var center = Vector2(0, 0)
		
		for pos_y in range(-load_distance, load_distance + 1):
			for pos_x in range(-load_distance, load_distance + 1):
				var position = Vector2(pos_x, pos_y)
				if position.distance_to(center) <= load_distance:
					adjacent_positions.append(position)
		
		# Sort vectors by the distance to the origin point
		adjacent_positions.sort_custom(func (a: Vector2, b: Vector2):
			return abs(a.x) + abs(a.y) < abs(b.x) + abs(b.y))
		
		return adjacent_positions).call()
		
	threadGen.start(_chunk_generator_thread)
	threadSave.start(_chunk_save_thread)

func preload_chunks():
	pass

func load_chunks():
	pass

func update_chunks():
	pass

func update(origin_position: Vector2):
	var origin_chunk := World.position_to_chunk(origin_position)
	
	# Unload / Render chunks
	for chunk_position in chunks.keys():
		var distance: float = chunk_position.distance_to(origin_chunk)
		
		if distance > load_distance:
			save_chunk_queue.append(chunks[chunk_position])
			world.remove_child(chunks[chunk_position])
			chunks.erase(chunk_position)
		elif distance > render_distance:
			chunks[chunk_position].visible = false
		else:
			chunks[chunk_position].visible = true
	
	mutexSave.lock()
	if saving_chunk == null and save_chunk_queue.size() > 0:
		saving_chunk = save_chunk_queue.pop_front()
		semaphoreSave.post()
	mutexSave.unlock()
	
	# Add chunks to load queuue
	for adjacent_chunk_position in adjacent_chunk_positions:
		var origin_adjacent_chunk := adjacent_chunk_position + origin_chunk
		var is_chunk_loaded := chunks.has(origin_adjacent_chunk)
		var is_chunk_loading := load_chunk_queue.has(origin_adjacent_chunk)
		
		if not is_chunk_loaded and not is_chunk_loading:
			load_chunk_queue.append(origin_adjacent_chunk)
	
	# Add loaded chunk
	mutexGen.lock()
	if loaded_chunk != null:
		world.add_child(loaded_chunk)
		chunks[loading_chunk] = loaded_chunk
		chunks[loading_chunk].visible = false
		
		load_chunk_queue.remove_at(0)
		loaded_chunk = null
		loading_chunk = null
	
	if loading_chunk == null and load_chunk_queue.size() > 0:
		loading_chunk = load_chunk_queue[0]
		semaphoreGen.post()
	mutexGen.unlock()

# Load and generate chunk thread
func get_heightmap(region: float) -> ChunkGenerator.Heightmap:
	var heightmap: ChunkGenerator.Heightmap = heightmap_store.get(region)
	
	if not heightmap:
		heightmap = WorldFiles.load_heightmap(world_name, region)
		
		if not heightmap:
			heightmap = chunkGenerator.generate_heightmap(region)
			WorldFiles.init_region_folder(world_name, region)
			WorldFiles.save_heightmap(world_name, heightmap)
			chunkGenerator.generate_structures(heightmap)
		
		for heightmap_region in heightmap_store.keys():
			if abs(heightmap_region - region) > preload_distance:
				heightmap_store.erase(heightmap_region)
		
		heightmap_store[region] = heightmap
	
	return heightmap

func get_chunk(chunk_position: Vector2) -> Chunk:
	
	var chunk: Chunk = WorldFiles.load_chunk(world_name, chunk_position)
	
	if not chunk:
		var chunk_heightmap := get_heightmap(chunk_position.x)
		chunk = chunkGenerator.generate_chunk(chunk_position, chunk_heightmap)
		WorldFiles.init_chunk_folder(world_name, chunk_position)
		
		var structure_data := WorldFiles.load_structure(world_name, chunk.local_position)
		
		if structure_data:
			for row in range(Chunk.BLOCK_NUM):
				for col in range(Chunk.BLOCK_NUM):
					if structure_data.foreground[row][col] != Block.Id.AIR:
						chunk.layers.foreground[row][col] = structure_data.foreground[row][col]

		chunk.is_modified = true
	
	return chunk

func _chunk_generator_thread():
	while is_manager_running:
		semaphoreGen.wait()
		
		mutexGen.lock()
		if loading_chunk == null:
			mutexGen.unlock()
			continue
		
		var loading_chunk_copy := Vector2(loading_chunk.x, loading_chunk.y)
		mutexGen.unlock()
		
		var chunk := get_chunk(loading_chunk_copy)
		Chunk.build(chunk)
		
		mutexGen.lock()
		loaded_chunk = chunk
		mutexGen.unlock()

# Save chunks thread
func save_chunk(chunk: Chunk):
	if chunk.is_modified:
		WorldFiles.save_chunk(world_name, chunk)
	chunk.queue_free()

func _chunk_save_thread():
	while is_manager_running:
		semaphoreSave.wait()
		
		mutexSave.lock()
		if saving_chunk == null:
			continue
		mutexSave.unlock()		
		
		# No lock required since this cannot be altered from ousside while not null
		save_chunk(saving_chunk)
		# This is a bit redundant since saving_chunk() already calls queue_free()
		saving_chunk = null

# End threads
func exit_tree():
	mutexGen.lock()
	mutexSave.lock()
	is_manager_running = false
	mutexGen.unlock()
	mutexSave.unlock()
	
	semaphoreGen.post()
	threadGen.wait_to_finish()
	
	semaphoreSave.post()
	threadSave.wait_to_finish()
	
	for save_chunk_queued in save_chunk_queue:
		save_chunk(save_chunk_queued)
	
	for chunk_position in chunks.keys():
		save_chunk(chunks[chunk_position])
