extends Node
class_name BlockBackground


func _ready():
	get_parent().modulate = Color(0.5, 0.5, 0.5)
	#get_parent().shape.size = Vector2(0, 0)
	get_parent().shape = null
