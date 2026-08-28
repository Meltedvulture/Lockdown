extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var hud = $UserInterface
@onready var myIDref = multiplayer.get_unique_id()
@onready var loading = $CanvasLayer/Loading

@onready var GUI = $GUIwindow
@onready var GUI_viewport = %SubViewport
@export var GUI_window: Window

@onready var Player = preload("res://controllers/fps_controller.tscn")

@onready var cop_spawns = $SpawnPoints2/Cops.get_children()
@onready var robber_spawns = $SpawnPoints2/Robber.get_children()

@onready var pauseHUD = $PauseLayer

var tracked = false
var player
var teams = {} # peer_id -> "Cop" or "Robber"

# Number of players currently in the game
var playercount = 0

# Maximum number of TOTAL players, including the host
const MAX_PLAYERS = 4

const PORT = 9999

var enet_peer = ENetMultiplayerPeer.new()

var debWin = preload("res://Menus/Debug.tscn")


var trapSetupMode = true
var totalItems = 0

func _on_host_button_pressed():

	main_menu.hide()
	hud.show()

	# Allow 2 remote clients.
	# The host counts as the third player.
	var error = enet_peer.create_server(PORT, MAX_PLAYERS - 1)

	if error != OK:
		print("Failed to create server. Error: ", error)
		return

	multiplayer.multiplayer_peer = enet_peer

	# Listen for players joining/leaving
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(remove_player)

	# Add the host as the first player
	add_player(multiplayer.get_unique_id())

	print("Server started.")
	print("Maximum players: ", MAX_PLAYERS)


func _on_join_button_pressed():

	main_menu.hide()
	loading.visible = true
	hud.show()

	var error

	if address_entry.text == "":
		error = enet_peer.create_client("127.0.0.1", PORT)
	else:
		error = enet_peer.create_client(address_entry.text, PORT)

	if error != OK:
		print("Failed to create client. Error: ", error)
		loading.hide()
		return

	multiplayer.multiplayer_peer = enet_peer

	loading.hide()


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Global.reserveLabel = %Reserve
	Global.interactionLabel = %InteractionLabel
	Global.clipLabel = %Clip
	Global.pointsLabel = %TotalValue
	Global.healthLabel = %Health
	Global.totalValue = 0
	GUI.hide()
	if Global.isMainMenu == false:
		main_menu.hide()
		hud.show()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print(Input.get_joy_name(0))
	get_viewport().set_embedding_subwindows(false)
	Global.recreatePlayers()
	Global.updateSpawnPoints(cop_spawns, robber_spawns)
	Global.respawnPlayers()
	
	
	#var DebugPanel = debWin.instantiate()
	#add_child(DebugPanel)
	#DebugPanel.visible = true

func _on_peer_connected(peer_id: int):

	print("Peer connected: ", peer_id)

	# This check is performed on the server.
	# If there are already 4 players, reject the new player.
	if !multiplayer.is_server():
		return

	if playercount >= MAX_PLAYERS:
		print("LOBBY FULL! Rejecting peer: ", peer_id)

		# Disconnect the fourth player
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)

		return

	# There is room, so add the player
	add_player(peer_id)




func add_player(peer_id: int):

	# Safety check
	if playercount >= MAX_PLAYERS:
		print("Cannot add player. Lobby is full.")
		return

	var new_player = Player.instantiate()

	new_player.name = str(peer_id)

	add_child(new_player)

	new_player.set_multiplayer_authority(peer_id)

	# Assign Cop or Robber
	assign_team(peer_id)

	tracked = true

	# Increase player count
	playercount += 1

	print("Player ", peer_id, " joined.")
	print("Playercount is ", playercount, "/", MAX_PLAYERS)
	print(multiplayer.get_unique_id())
	Global.playerJoined.emit()




func remove_player(peer_id: int):

	print("Player ", peer_id, " disconnected.")

	player = get_node_or_null(str(peer_id))

	if player:
		player.queue_free()

	# Remove them from the team dictionary
	if teams.has(peer_id):
		teams.erase(peer_id)

	# Decrease player count
	playercount -= 1

	# Prevent negative values
	playercount = max(playercount, 0)

	print("Playercount is ", playercount, "/", MAX_PLAYERS)


func _on_single_player_button_pressed():

	main_menu.hide()
	hud.show()

	var my_id = multiplayer.get_unique_id()

	add_player(my_id)



func assign_team(id):

	# Only the server assigns teams
	if !multiplayer.is_server():
		return

	Global.cop_count = 0
	Global.robber_count = 0
	Global.aliveCopCount = 0
	Global.aliveRobberCount = 0

	for t in teams.values():

		if t == "Cop":
			Global.cop_count += 1
			Global.aliveCopCount += 1

		elif t == "Robber":
			Global.robber_count += 1
			Global.aliveRobberCount += 1

	var team

	if Global.cop_count > Global.robber_count:
		team = "Robber"

	elif Global.robber_count > Global.cop_count:
		team = "Cop"


	else:
		team = "Cop" if randi() % 2 == 0 else "Robber"

	teams[id] = team

	print("Player ", id, " assigned to ", team)
	
	if team == "Cop":
		Global.aliveCopCount += 1
		print("COP IS ALIVE")
	elif team == "Robber":
		Global.aliveRobberCount += 1
		print("ROBBER IS ALOVE")

	# Update local player's team
	if id == multiplayer.get_unique_id():

		Global.myCurrentTeam = team
		Global.player.updatePlayerModel()

	# Tell all clients the team assignment
	rpc("receive_team_assignment", id, team)

	# Spawn player
	spawn_player(id, team)


func spawn_player(id, team):

	var player_node = get_node_or_null(str(id))

	if player_node == null:
		print("Could not find player node: ", id)
		return

	var spawn_point

	if team == "Cop":

		spawn_point = cop_spawns.pick_random()

		Global.player.spawnpoint = cop_spawns

	else:

		spawn_point = robber_spawns.pick_random()

		Global.player.spawnpoint = robber_spawns

	player_node.global_position = spawn_point.global_position



@rpc("any_peer", "reliable")
func receive_team_assignment(id, team):

	teams[id] = team

	if id == multiplayer.get_unique_id():

		Global.myCurrentTeam = team
		Global.player.updatePlayerModel()

	var player_node = get_node_or_null(str(id))

	if player_node == null:
		return

	var spawn_point

	if team == "Cop":

		spawn_point = cop_spawns.pick_random()

	else:

		spawn_point = robber_spawns.pick_random()

	player_node.global_position = spawn_point.global_position




func upnp_setup():

	var upnp = UPNP.new()

	var discover_result = upnp.discover()

	assert(
		discover_result == UPNP.UPNP_RESULT_SUCCESS,
		"UPNP Discover Failed! Error %s" % discover_result
	)

	assert(
		upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(),
		"UPNP Invalid Gateway!"
	)

	var map_result = upnp.add_port_mapping(PORT)

	assert(
		map_result == UPNP.UPNP_RESULT_SUCCESS,
		"UPNP Port Mapping Failed! Error %s" % map_result
	)

	print("Success! Join Address: %s" % upnp.query_external_address())



func _physics_process(delta):


	if Input.is_action_just_pressed("PauseMenu"):

		pause()

func _unhandled_input(_event):

	if Input.is_action_just_pressed("quit"):

		get_tree().quit()



func pause():

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:

		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Global.isPaused = true

	elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:

		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Global.isPaused = false

	if Global.isPaused == true:

		pauseHUD.visible = true

	else:

		pauseHUD.visible = false

	print(str(Global.isPaused))



func _on_Quit_button_pressed() -> void:

	get_tree().quit()



var minitask = preload(
	"res://gameMechanics/hacking_minitask.tscn"
).instantiate()

var active_instance: Node = null


func _GUI_window_open(_body: Player) -> void:

	if _body.is_multiplayer_authority():

		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		Global.taskMode = true

		GUI.show()

		GUI_viewport.add_child(minitask)

		print("player interacted with minitask")

		# Player quits window

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


func _on_exit_game_pressed() -> void:

	get_tree().quit()

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
