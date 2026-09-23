extends Node3D

@onready var animationPlayer = $AnimationPlayer
@onready var timer = $Timer
@onready var blade = $Blade
@onready var hurtArea = $Blade/HurtArea
var sawDanger = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	blade.rotation.y += 10 * delta


func _on_timer_timeout() -> void:
	sawDanger = !sawDanger
	changeSawState()


func changeSawState():
	if sawDanger == true:
		animationPlayer.play("sawbladeUp")
	else:
		animationPlayer.play("sawbladeDown")


func _on_damage_timer_timeout() -> void:
	var bodies = hurtArea.get_overlapping_bodies()
	for i in bodies:
		if i.has_method("take_damage"):
			i.take_damage(5, "bullet", "Cop")  # Deal damage to the enemy
