class_name WorldManager


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
	var heightmaps: Dictionary
	var world_name: String
	var preload_distance: int
	
	var regionGenerator: WorldGenerator.RegionGenerator
	var structureGenerator: WorldGenerator.StructureGenerator
	
	var is_loading: bool
	var is_loaded: bool
	var region_queue: Array[float]
	var loading_region: float
	var loaded_heightmap: WorldGenerator.Heightmap
	
	func _init(_heightmaps: Dictionary, world_seed: int, _world_name: String, _preload_distance: int):
		super()
		
		heightmaps = _heightmaps
		world_name = _world_name
		preload_distance = _preload_distance
		
		regionGenerator = WorldGenerator.RegionGenerator.new(world_seed)
		structureGenerator = WorldGenerator.StructureGenerator.new(world_seed)
		
		is_loading = false
		is_loaded = false
		region_queue = []
		loading_region = 0
		loaded_heightmap = null
	
	func load_region(region: float) -> WorldGenerator.Heightmap:
		var heightmap: WorldGenerator.Heightmap = heightmaps.get(region)
			
		if not heightmap:
			heightmap = WorldFiles.load_heightmap(world_name, region)
			
			if not heightmap:
				heightmap = regionGenerator.generate_heightmap(int(region))
				WorldFiles.init_region_folder(world_name, region)
				WorldFiles.save_heightmap(world_name, heightmap)
				
				var structures := structureGenerator.generate_structures(heightmap)
				for structure_position in structures.keys():
					WorldFiles.init_chunk_folder(world_name, structure_position)
					WorldFiles.save_structure(world_name, structure_position, structures[structure_position])
		
		return heightmap
	
	func _excecution_thread():
		while is_running:
			semaphore.wait()
			
			mutex.lock()
			var loading_region_copy := loading_region
			mutex.unlock()
			
			var heightmap := load_region(loading_region_copy)
			
			mutex.lock()
			is_loading = false
			is_loaded = true
			
			loaded_heightmap = heightmap
			mutex.unlock()
	
	func update(origin_chunk: Vector2):
		for heightmap_region in heightmaps.keys():
			if abs(heightmap_region - origin_chunk.x) > preload_distance:
				heightmaps.erase(heightmap_region)
		
		for region in range(origin_chunk.x - preload_distance, origin_chunk.x + preload_distance + 1):
			if not heightmaps.has(region) and not region in region_queue:
				region_queue.append(region)
		
		mutex.lock()
		if is_loaded:
			is_loaded = false
			
			region_queue.remove_at(0)
			heightmaps[loading_region] = loaded_heightmap
		if not is_loading and region_queue.size() > 0:
			is_loading = true
			
			loading_region = region_queue[0]
			semaphore.post()
		mutex.unlock()
	
	func finish():
		super.finish()
		
		for region in region_queue:
			load_region(region)


class ChunkLoader extends MultiThread:
	signal chunk_loaded(chunk: Chunk)
	
	var chunks: Dictionary
	var heightmaps: Dictionary
	var world_name: String
	var load_distance: int
	
	var chunkGenerator: WorldGenerator.ChunkGenerator
	
	var is_loading: bool
	var is_loaded: bool
	var chunk_queue: Array[Vector2]
	var loading_chunk: Vector2
	var loaded_chunk: Chunk
	
	func _init(_chunks: Dictionary, _heightmaps: Dictionary,  world_seed: int, _world_name: String,  _load_distance: int):
		super()
		
		chunks = _chunks
		heightmaps = _heightmaps
		world_name = _world_name
		load_distance = _load_distance
		
		chunkGenerator = WorldGenerator.ChunkGenerator.new(world_seed)
		
		is_loading = false
		is_loaded = false
		chunk_queue = []
		loading_chunk = Vector2.ZERO
		loaded_chunk = null
	
	func _excecution_thread():
		while is_running:
			semaphore.wait()
			
			mutex.lock()
			var loading_chunk_copy := Vector2(loading_chunk)
			var heightmap_copy: WorldGenerator.Heightmap = heightmaps.get(loading_chunk_copy.x)
			mutex.unlock()
			
			if heightmap_copy == null:
				heightmap_copy = WorldFiles.load_heightmap(world_name, loading_chunk_copy.x)
			
			var chunk := WorldFiles.load_chunk(world_name, loading_chunk_copy)
			
			if chunk == null:
				chunk = chunkGenerator.generate_chunk(loading_chunk_copy, heightmap_copy)
				chunk.is_modified = true
				
				WorldFiles.init_chunk_folder(world_name, loading_chunk_copy)
				var structure_data := WorldFiles.load_structure(world_name, chunk.local_position)
		
				if structure_data:
					for row in range(Chunk.BLOCK_NUM):
						for col in range(Chunk.BLOCK_NUM):
							if structure_data.foreground[row][col] != Block.Id.AIR:
								chunk.layers.foreground[row][col] = structure_data.foreground[row][col]
			
			Chunk.build(chunk)
			
			mutex.lock()
			is_loading = false
			is_loaded = true
			
			loaded_chunk = chunk
			mutex.unlock()
	
	func update(origin_chunk: Vector2):
		for chunk_y in range(-load_distance, load_distance + 1):
			for chunk_x in range(-load_distance, load_distance + 1):
				var chunk_position := Vector2(chunk_x, chunk_y) + origin_chunk
				
				if origin_chunk.distance_to(chunk_position) <= load_distance and not chunks.has(chunk_position):
					if not chunk_position in chunk_queue and heightmaps.has(chunk_position.x):
						chunk_queue.append(chunk_position)
		
		mutex.lock()
		if is_loaded:
			is_loaded = false
			
			chunk_queue.remove_at(0)
			chunks[loading_chunk] = loaded_chunk
			chunk_loaded.emit(loaded_chunk)
		if not is_loading and chunk_queue.size() > 0:
			is_loading = true
			
			loading_chunk = chunk_queue[0]
			semaphore.post()
		mutex.unlock()


class ChunkSaver extends MultiThread:
	signal chunk_unloaded(chunk: Chunk)
	
	var chunks: Dictionary
	var world_name: String
	var render_distance: int
	var load_distance: int
	
	var is_saving: bool
	var is_saved: bool
	var chunk_queue: Array[Chunk]
	var saving_chunk: Chunk
	
	func _init(_chunks: Dictionary, _world_name: String, _render_distance: int, _load_distance: int):
		super()
		
		chunks = _chunks
		world_name = _world_name
		render_distance = _render_distance
		load_distance = _load_distance
		
		is_saving = false
		is_saved = false
		chunk_queue = []
		saving_chunk = null
	
	func save_chunk(chunk: Chunk):
		WorldFiles.save_chunk(world_name, chunk)
	
	func _excecution_thread():
		while is_running:
			semaphore.wait()
			
			save_chunk(saving_chunk)
			
			mutex.lock()
			is_saving = false
			is_saved = true
			saving_chunk = null
			mutex.unlock()
	
	func update(origin_chunk: Vector2):
		for chunk_position in chunks.keys():
			var chunk: Chunk = chunks[chunk_position]
			var distance := origin_chunk.distance_to(chunk_position)
			
			if distance > load_distance and chunk.is_modified:
				if not chunk in chunk_queue:
					chunk_queue.append(chunk)
					chunks.erase(chunk_position)
			elif distance > render_distance:
				chunk.visible = false
			else:
				chunk.visible = true
		
		mutex.lock()
		if is_saved:
			is_saved = false
		if not is_saving and chunk_queue.size() > 0:
			is_saving = true
			
			saving_chunk = chunk_queue.pop_front()
			chunk_unloaded.emit(saving_chunk)
			semaphore.post()
		mutex.unlock()
	
	func finish():
		super.finish()
		
		for chunk in chunk_queue:
			save_chunk(chunk)
		
		for chunk_position in chunks.keys():
			if chunks[chunk_position].is_modified:
				save_chunk(chunks[chunk_position])


signal chunk_loaded(chunk: Chunk)
signal chunk_unloaded(chunk: Chunk)


var chunks: Dictionary
var heightmaps: Dictionary

var world_seed: int
var world_name: String

var render_distance: int
var load_distance: int
var preload_distance: int

var regionLoader: RegionLoader
var chunkLoader: ChunkLoader
var chunkSaver: ChunkSaver

func _init(_chunks: Dictionary, _world_seed: int, _world_name: String, _render_distance = 0):
	chunks = _chunks
	heightmaps = {}
	
	world_seed = _world_seed
	world_name = _world_name
	
	render_distance = _render_distance
	load_distance = render_distance
	preload_distance = load_distance
	
	regionLoader = RegionLoader.new(heightmaps, world_seed, world_name, preload_distance)
	chunkLoader = ChunkLoader.new(chunks, heightmaps, world_seed, world_name, load_distance)
	chunkSaver = ChunkSaver.new(chunks, world_name, render_distance, load_distance)
	
	chunkLoader.chunk_loaded.connect(_on_chunk_loaded)
	chunkSaver.chunk_unloaded.connect(_on_chunk_unloaded)

func update(origin_position: Vector2):
	regionLoader.update(origin_position)
	chunkLoader.update(origin_position)
	chunkSaver.update(origin_position)

func _on_chunk_loaded(chunk: Chunk):
	chunk_loaded.emit(chunk)

func _on_chunk_unloaded(chunk: Chunk):
	chunk_unloaded.emit(chunk)

# End threads
func exit_tree():
	regionLoader.finish()
	chunkLoader.finish()
	chunkSaver.finish()
