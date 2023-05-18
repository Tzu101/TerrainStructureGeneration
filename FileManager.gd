class_name FileManager


const USER_FOLDER: String = 'user://'

static func _to_user_path(path: String) -> String:
	var user_path := '%s%s' % [USER_FOLDER, path]
	return user_path

static func make_folder(folder_name):
	var directory := DirAccess.open(USER_FOLDER)
	directory.make_dir(folder_name)

static func move_to_trash(path: String):
	OS.move_to_trash(ProjectSettings.globalize_path(_to_user_path(path)))

# If used on a folder it only works if the folder is empty
static func delete_permanently(path: String):
	DirAccess.remove_absolute(_to_user_path(path))

static func is_folder(folder_name) -> bool:
	return DirAccess.dir_exists_absolute(_to_user_path(folder_name))

static func is_file(file_name) -> bool:
	return FileAccess.file_exists(_to_user_path(file_name))

static func save_16_bit(file_name: String, file_data: Array):
	var file := FileAccess.open(_to_user_path(file_name), FileAccess.WRITE)
	
	if not file:
		return
	
	for number in file_data:
		file.store_16(number)
		
	file.close()

static func load_16_bit(file_name: String) -> Array[int]:
	var file := FileAccess.open(_to_user_path(file_name), FileAccess.READ)
	
	if not file:
		return []
	
	var file_data: Array[int] = []
	while not file.eof_reached():
		file_data.append(file.get_16())
	
	file.close()
	return file_data


static func save_64_bit(file_name: String, file_data: Array):
	var file := FileAccess.open(_to_user_path(file_name), FileAccess.WRITE)
	
	if not file:
		return
	
	for number in file_data:
		file.store_64(number)
		
	file.close()

static func load_64_bit(file_name: String) -> Array[int]:
	var file := FileAccess.open(_to_user_path(file_name), FileAccess.READ)
	
	if not file:
		return []
	
	var file_data: Array[int] = []
	while not file.eof_reached():
		file_data.append(file.get_64())
	
	file.close()
	return file_data
