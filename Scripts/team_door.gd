extends Node3D

@export var inverted_open = false
@onready var collision = $StaticBody3D/CollisionShape3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	collision.disabled = get_tree().current_scene.trapSetupMode
	
	if inverted_open:
		collision.disabled = !get_tree().current_scene.trapSetupMode
