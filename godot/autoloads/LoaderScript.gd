extends Node


func load_folders():
	var sceneList : PackedStringArray
	var listdirs = DirAccess.get_directories_at("res://views")
	print(listdirs)
	for dir in listdirs:
		sceneList.append_array(DirAccess.get_files_at("res://views/"+dir))
