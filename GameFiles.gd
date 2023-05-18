class_name GameFiles


const WORLDS_FOLDER: String = 'worlds'

static func init_game_files() -> void:
	FileManager.make_folder(WORLDS_FOLDER)
