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

func spawnItem():
	if multiplayer.get_unique_id() == 1:
		var dropInstance = weaponDrop.instantiate()
		get_tree().root.get_node("World").add_child(dropInstance)
		var loadedItem = itemPaths[rng.randi_range(0, itemPaths.size()-1)]
		dropInstance.global_position = dropLocation.global_position
		dropInstance.setWeapon(loadedItem)
		dropInstance.setModel(loadedItem)
		dropInstance.setAttribute("isItem", true)
		get_tree().current_scene.totalItems += 1
		rpc("replicateDroppedItem", loadedItem, dropLocation.global_position)
	
@rpc("any_peer")
func replicateDroppedItem(weapon, dropPos):
	var dropInstance = weaponDrop.instantiate()
	get_tree().root.get_node("World").add_child(dropInstance)
	dropInstance.global_position = dropPos
	dropInstance.setWeapon(weapon)
	dropInstance.setModel(weapon)
	dropInstance.setAttribute("isItem", true)
	get_tree().current_scene.totalItems += 1
