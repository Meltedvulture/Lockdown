@tool

extends Node
signal roundReset

var player
var playerPoints = 0:
	set(value):
		playerPoints = value
		updatePoints()
var playerHealth = 100:
	set(value):
		healthLabel.text = str(value)
		playerHealth = value
var playerCamera
var debug
var weaponManager
var reserveLabel : Label
var clipLabel : Label
var pointsLabel : Label
var healthLabel: Label
var interactionLabel: Label
var isPaused = false
var myCurrentTeam : String

var totalValue = 0

var taskMode = false
var isMainMenu = true

var copSpawnpoints
var robberSpawnpoints
var cop_count = 0
var robber_count = 0
var aliveCopCount = 0
var aliveRobberCount = 0

func updateLabels(clipAmmo, reserveAmmo):
	clipLabel.text = str(clipAmmo)
	reserveLabel.text = str(reserveAmmo)

func updatePoints():
	pointsLabel.text = str(totalValue)

func updateHealth():
	#DEPRECATED FUNCTION but still here for old code
	healthLabel.text = str(playerHealth)

# if status is true, increases the size of the window and scales on-screen elements to window size
# allows for better viewing on retina (or similar resolution) displays
func high_resolution_display_mode(status):
	if status == true:
		if OS.get_name()=="macOS": # Checks if MacOS. Unsure if required.
			print("resizine window")
			get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT # scales UI elements to window size.
			DisplayServer.window_set_size(Vector2i(2560, 1440)) # Sets windows dimensions
			get_window().move_to_center() # Centres the screen

# Called when the node enters the scene tree for the first time.
func _ready():
	high_resolution_display_mode(true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

@rpc("any_peer", "reliable")
func replicateSpecificObject(bodyName, function, arg1):
	var object = get_tree().get_root().get_node(bodyName)
	if arg1:
		object.call(function, arg1)
	else:
		object.call(function)

@rpc("reliable", "any_peer")
func changeScene(sceneString):
	var players = get_tree().get_nodes_in_group("player")
	for i in players:
		i.reparent(get_tree().root, false) 
	get_tree().change_scene_to_file(sceneString)

func recreatePlayers():
	var players = get_tree().get_nodes_in_group("player")
	if players:
		for o in players:
			o.reparent(get_tree().root.get_node("World"), false)

func updateSpawnPoints(cop_spawns, robber_spawns):
	copSpawnpoints = cop_spawns
	robberSpawnpoints = robber_spawns

func respawnPlayers():
	var players = get_tree().get_nodes_in_group("player")
	if players:
		for o in players:
			if o.is_multiplayer_authority() == true:
				if Global.myCurrentTeam == "Robber":
					o.global_position = robberSpawnpoints.pick_random().global_position 
				else:
					o.global_position = copSpawnpoints.pick_random().global_position
	 
	
	#Recursivley gather all players and move them to root node
	#Change Scene
	#Move them back in
	
	

#This function is for adding things to in game debug menu
#Format:
#Global.debug.addProperty("Display Name", Variable, Position on debug board)

#Example formatting
#Global.debug.addProperty("Stamina", stamina, 2)

#When adding anything to the scene that needs to be deleted on a scene change, use this:
#get_tree().root.get_node("World")
#This adds it to the scene root and not the game root
#This should not be used for persistent objects (such as the player/s)
