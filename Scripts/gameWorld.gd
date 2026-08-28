extends Node

@onready var hud = $UserInterface
@onready var myIDref = multiplayer.get_unique_id()

@onready var GUI = %GUIwindow
@onready var GUI_viewport = %SubViewport
@export var GUI_window: Window 

@onready var Player = preload("res://controllers/fps_controller.tscn")
#@onready var Player = $Player
@onready var cop_spawns = $SpawnPoints/Cops.get_children()
@onready var robber_spawns = $SpawnPoints/Robber.get_children()

@onready var pauseHUD = $PauseLayer
var tracked = false
var player
var teams = {} # peer_id -> "Cop" or "Robber"
var playercount = 0
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()

#Game Manager Variables
var trapSetupMode = true
var totalItems = 0

func upnp_setup():
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP Discover Failed! Error %s" % discover_result)

	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), "UPNP Invalid Gateway!")

	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP Port Mapping Failed! Error %s" % map_result)
	
	print("Success! Join Address: %s" % upnp.query_external_address())

func _physics_process(delta):
	if Input.is_action_just_pressed("PauseMenu"):
		pause()
	#if tracked:
		#get_tree().call_group("enemy", "update_target_location", player.global_transform.origin)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Global.reserveLabel = %Reserve
	Global.interactionLabel = %InteractionLabel
	Global.clipLabel = %Clip
	Global.pointsLabel = %TotalValue
	Global.healthLabel = %Health
	Global.totalValue = 0
	GUI.hide()
	print(Input.get_joy_name(0))
	get_viewport().set_embedding_subwindows(false)
	Global.recreatePlayers()
	Global.updateSpawnPoints(cop_spawns, robber_spawns)
	Global.respawnPlayers()
	#var DebugPanel = debWin.instantiate()
	#add_child(DebugPanel)
	#DebugPanel.visible = true

func _unhandled_input(_event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

		
func pause(): #this probably isnt the best way to do this but it works
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE #Un-captures the mouse
		Global.isPaused = true
	elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED #Re-captures the mouse
		Global.isPaused = false
	if Global.isPaused == true:
		pauseHUD.visible = true
	elif Global.isPaused == false:
		pauseHUD.visible = false
	print(str(Global.isPaused))
	
# GUI window code :

var minitask = preload("res://gameMechanics/hacking_minitask.tscn").instantiate()
var active_instance: Node = null

func _GUI_window_open(_body: Player) -> void:
	if _body.is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Release mouse
		Global.taskMode = true
		GUI.show()
		GUI_viewport.add_child(minitask)
		print("player interacted with minitask")

# player quits window
		if GUI_window != null:
			swap_to_new_instance()
			GUI_window.emit_signal("close_requested")
			Global.taskMode = false
			print("player closed minitask")

func swap_to_new_instance():
	if is_instance_valid(active_instance):
		active_instance.queue_free()
		var new_instance = minitask.instantiate()
		add_child(new_instance)
		active_instance = new_instance

func showAnnounceText(text : String):
	var announceBox = $"UserInterface/Spawn Text"
	var announceLabel = %AnnounceLabel
	announceLabel.text = text
	announceBox.show()
	await get_tree().create_timer(3.0).timeout
	announceBox.hide()

@rpc("reliable", "any_peer")
func exitTrapSetup():
	if trapSetupMode == true:
		trapSetupMode = false
		Global.roundReset.emit()
		Global.respawnPlayers()
		showAnnounceText("Rob stuff I guess")

func resetRound():
	Global.roundReset.emit()
	Global.respawnPlayers()
	trapSetupMode = true
	rpc("recieveReset")
	if Global.myCurrentTeam == "Cop":
		showAnnounceText("Trap setup mode")
		
@rpc("reliable", "any_peer")
func recieveReset():
	Global.roundReset.emit()
	Global.respawnPlayers()
	trapSetupMode = true
	if Global.myCurrentTeam == "Cop":
		showAnnounceText("Trap setup mode")

@rpc("reliable", "call_local", "any_peer")
func updateAlivePlayers(team):
	if multiplayer.get_unique_id() == 1:
		if team == "Cop":
			Global.aliveCopCount -= 1
		elif team == "Robber":
			Global.aliveRobberCount -= 1
		
		if Global.aliveCopCount <= 0 or Global.aliveRobberCount <= 0:
			Global.aliveCopCount = 0
			Global.aliveRobberCount = 0
			for t in teams.values():

				if t == "Cop":
					Global.aliveCopCount += 1

				elif t == "Robber":
					Global.aliveRobberCount += 1
			resetRound()
