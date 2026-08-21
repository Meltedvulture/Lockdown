extends Node3D

@onready var dropLocation = $"Item Spawn Location"
var rng = RandomNumberGenerator.new()
var weaponDrop = preload("res://Scenes/Weapon Drop.tscn")
var itemPaths = [
"res://Items/Item Files/Gem.tres",
"res://Items/Item Files/Goldbar.tres",
"res://Items/Item Files/Painting.tres"

]



func _ready() -> void:
	rng.randomize()
	Global.roundReset.connect(spawnItem)
	if multiplayer.is_server():
		call_deferred("spawnItem")

func spawnItem():
	var dropInstance = weaponDrop.instantiate()
	get_tree().root.get_node("World").add_child(dropInstance)
	var loadedItem = itemPaths[rng.randi_range(0, itemPaths.size()-1)]
	dropInstance.global_position = dropLocation.global_position
	dropInstance.setWeapon(loadedItem)
	dropInstance.setModel(loadedItem)
	dropInstance.setAttribute("isItem", true)
	get_tree().current_scene.totalItems += 1
