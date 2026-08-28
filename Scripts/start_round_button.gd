extends StaticBody3D

var objectName : String = "Start the round"
var teamFilter = "Both"

func _ready():
	pass

func update():
	pass

func interact():
	if get_tree().current_scene.trapSetupMode == true:
		get_tree().current_scene.exitTrapSetup()
		get_tree().current_scene.exitTrapSetup.rpc()
