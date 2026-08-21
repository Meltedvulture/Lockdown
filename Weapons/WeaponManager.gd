

extends Node3D

class_name WeaponController

# OnReady variables
@onready var weaponMesh : MeshInstance3D = %WeaponMesh
@onready var weaponMagazine : MeshInstance3D = %WeaponMagazine
@onready var weaponBolt : MeshInstance3D = %WeaponBolt
@onready var weaponShadow : MeshInstance3D = %WeaponShadow
@onready var bulletSpawnPoint = %"Bullet Spawn"

# Exported variables
@export var weaponType : Weapons:
	set(value):
		weaponType = value
		if Engine.is_editor_hint():
			loadWeapon()

@export var swaySpeed : float = 1.2
@export var reset : bool = false:
	set(value):
		reset = value
		if Engine.is_editor_hint():
			loadWeapon()


#********Animation names Index:********
		# "fullReload"
		# "emptyReload"
		# "startReload"
		# "finishReload"
		# "shellReload"
		# "boltCycle"
		# "shoot"
		
		# Documemtation stuff:
		# Magazine reloads are for guns where all ammo is loaded at once
		# Shell reloads are for guns where they load individual rounds

# Internal variables


@export var weaponAnimationPlayer : AnimationPlayer

var weaponDrop = preload("res://Scenes/Weapon Drop.tscn")



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not is_multiplayer_authority(): return
	Global.weaponManager = self
	loadWeapon()
	addWeapon("res://Weapons/Blaster.tres", true, 0, 0)
	
	#Checks if the player has spawned before, thus not giving new equipment
	#Might not be needed
	if weaponGlobal.hasSpawned == false:
		weaponGlobal.hasSpawned = true
	Global.clipLabel.text = str(weaponGlobal.clipAmmo)
	Global.reserveLabel.text = str(weaponGlobal.reserveAmmo)
	
func _input(event):
	if !Engine.is_editor_hint():
		if not is_multiplayer_authority(): return
		if event.is_action_pressed("weaponDown"):
			if !weaponAnimationPlayer.is_playing():
				switchWeapon(1)

		if event.is_action_pressed("weaponUp"):
			if !weaponAnimationPlayer.is_playing():
				switchWeapon(-1)
		
		if Input.is_action_just_pressed("dropWeapon"):
			dropWeapon()
		
	
	if event is InputEventMouseMotion:
		weaponGlobal.mouseMovement = event.relative

#This function adds the specified weapon to the players inventory
#This checks if the inventory is full, if there is a free slot or if the hand is free
#If all slots full then replace current weapon, if a slot is free then fill that slot
#If hand is free then give to hand
func addWeapon(WeaponPath: String, defaultStats: bool, clip: int, reserve: int):
	#If hand is free then give to hand
	if weaponType == load("res://Weapons/Empty Weapon.tres") or null:
		weaponGlobal.weaponInventory[weaponGlobal.currentWeaponIndex] = WeaponPath
		var weapon = load(WeaponPath)
		#weaponGlobal.currentWeaponPath = WeaponPath
		if defaultStats == true:
			weaponGlobal.weaponAmmoInventory[weaponGlobal.currentWeaponIndex] = [weapon.clip, weapon.reserve]
		else:
			weaponGlobal.weaponAmmoInventory[weaponGlobal.currentWeaponIndex] = [clip, reserve]
	#if a slot is free then fill that slot
	else:
		if weaponGlobal.weaponInventory.size() < weaponGlobal.maxInventorySize:
			weaponGlobal.weaponInventory.append(WeaponPath)
			var weapon = load(WeaponPath)
			#weaponGlobal.currentWeaponPath = WeaponPath
			if defaultStats == true:
				weaponGlobal.weaponAmmoInventory.append([weapon.clip, weapon.reserve])
			else:
				weaponGlobal.weaponAmmoInventory.append([clip, reserve])
		#If all slots full then replace current weapon
		else:
			if weaponType != load("res://Weapons/Empty Weapon.tres"):
				dropWeapon()
			weaponGlobal.weaponInventory[weaponGlobal.currentWeaponIndex] = WeaponPath
			var weapon = load(WeaponPath)
			#weaponGlobal.currentWeaponPath = WeaponPath
			if defaultStats == true:
				weaponGlobal.weaponAmmoInventory[weaponGlobal.currentWeaponIndex] = [weapon.clip, weapon.reserve]
			else:
				weaponGlobal.weaponAmmoInventory[weaponGlobal.currentWeaponIndex] = [clip, reserve]
	loadWeapon()
	Global.updateLabels(weaponGlobal.clipAmmo, weaponGlobal.reserveAmmo) 


#Both these functions are for weapon swapping, nothing else or of interest
func switchWeapon(direction: int) -> void:
	if not is_multiplayer_authority(): return
	# Increment or decrement the current weapon index based on the direction
	weaponGlobal.currentWeaponIndex += direction
	
	# Use modulo (%) to loop the index within the bounds of the array
	# Ensure it works correctly for negative indices by adding maxInventorySize before taking the modulus
	weaponGlobal.currentWeaponIndex = wrap_index(weaponGlobal.currentWeaponIndex, weaponGlobal.weaponInventory.size())
	# Equip the weapon at the new index
	loadWeapon()
	
	
func wrap_index(index: int, size: int) -> int:
	# Wrap the index to stay within [0, size)
	if size == 0:
		return 0  # Avoid division by zero if the inventory is empty
	return (index % size + size) % size

#This function is called when you want to load the currently held weapon
func loadWeapon():
	#Checks if you are the player
	#Fallback in case if you have a null weapon and not "empty weapon"
	if not is_multiplayer_authority(): return
	if weaponType == null:
		return

	#This runs in game and loads the current weapon from the given path, usually the inventory
	#Otherwise loads an empty weapon as a fallback
	if !Engine.is_editor_hint():
		if weaponGlobal.weaponInventory[weaponGlobal.currentWeaponIndex] != null:
			weaponType = load(weaponGlobal.weaponInventory[weaponGlobal.currentWeaponIndex])
		else:
			weaponType = load("res://Weapons/Empty Weapon.tres")
		
	
	#These variables hold all the data from the weapon and are access everywhere
	#in this script for various core functionality
	
	weaponGlobal.weaponName = weaponType.name
	weaponMesh.mesh = weaponType.mesh
	weaponMagazine.mesh = weaponType.magazine
	weaponBolt.mesh = weaponType.bolt
	weaponShadow.mesh = weaponType.mesh
	weaponGlobal.weaponBulletPhysics = weaponType.bulletPhysics
	#Weapon Weights need to be persistent across whole inventory
	#with += it infinetly adds weight if swapping weapons
	weaponGlobal.inventoryWeight = weaponType.weight
	
	#Checks if the projectile based weapon has a scene, otherwise skips loading it
	if !Engine.is_editor_hint():
		if weaponType.bulletScene != "" or weaponType.bulletScene != "<null>":
			weaponGlobal.weaponBulletScene = load(weaponType.bulletScene)
	
	#Gun Orientation
	position = weaponType.position
	rotation_degrees = weaponType.rotation
	scale = weaponType.scale
	#Magazine Orientation
	weaponMagazine.position = weaponType.magazinePosition
	weaponMagazine.rotation_degrees = weaponType.magazineRotation
	weaponMagazine.scale = weaponType.magazineScale
	#Bolt Orientation
	weaponBolt.position = weaponType.boltPosition
	weaponBolt.rotation_degrees = weaponType.boltRotation
	weaponBolt.scale = weaponType.boltScale
	weaponShadow.visible = weaponType.shadow

	#Loads the sway information, does not run in editor
	if !Engine.is_editor_hint():
		weaponGlobal.idleSwayAdjustment = weaponType.idleSwayAdjustment
		weaponGlobal.idleSwayRotationStrength = weaponType.idleSwayRotationStrength
		weaponGlobal.randomSwayAmount = weaponType.randomSwayAmount
		weaponGlobal.shotgun = weaponType.shotgun
		weaponGlobal.fireMode = weaponType.fireMode
		weaponGlobal.reloadMode = weaponType.reloadMode

	# Load ammo from weaponAmmoInventory instead of resetting to default
	
	#Otherwise it loads it from the file, which is usually the default values, and sets it in the inventory
	#Usually for new weapons
	if !Engine.is_editor_hint():
		if weaponGlobal.currentWeaponIndex < weaponGlobal.weaponAmmoInventory.size():
			var ammo_data = weaponGlobal.weaponAmmoInventory[weaponGlobal.currentWeaponIndex]
			weaponGlobal.clipAmmo = ammo_data[0]
			weaponGlobal.reserveAmmo = ammo_data[1]
			if weaponType == load("res://Weapons/Empty Weapon.tres"):
				ammo_data[0] = 0
				ammo_data[1] = 0
				weaponGlobal.clipAmmo = 0
				weaponGlobal.reserveAmmo = 0
		else:
			weaponGlobal.clipAmmo = weaponType.clip
			weaponGlobal.reserveAmmo = weaponType.reserve
			weaponGlobal.weaponAmmoInventory.append([weaponGlobal.clipAmmo, weaponGlobal.reserveAmmo])
	
	#Sets the some misc stats and text
	if !Engine.is_editor_hint():
		weaponGlobal.maxClipAmmo = weaponType.maxClip
		Global.clipLabel.text = str(weaponGlobal.clipAmmo)
		Global.reserveLabel.text = str(weaponGlobal.reserveAmmo)
		weaponGlobal.time_per_shot = 60.0 / weaponType.rpm
		weaponGlobal.weaponAccuracy = weaponType.Accuracy
		weaponGlobal.verticalRecoil = weaponType.verticalRecoil
		weaponGlobal.horizontalRecoil = weaponType.horizontalRecoil
		Global.rpc("replicateSpecificObject", str(get_path()), "replicateWeaponVisual", weaponGlobal.weaponInventory[weaponGlobal.currentWeaponIndex])
		apply_clip_and_fov_shader_to_view_model(self, -1.0)
		

#Controls the sway of the weapon given the values from the loaded weapon
func sway_weapon(delta, isIdle: bool) -> void:
	if weaponType == null:
		return
		
	# Clamp mouse movement
	weaponGlobal.mouseMovement.x = clamp(weaponGlobal.mouseMovement.x, weaponType.sway_min.x, weaponType.sway_max.x)
	weaponGlobal.mouseMovement.y = clamp(weaponGlobal.mouseMovement.y, weaponType.sway_min.y, weaponType.sway_max.y)
	
	#Idle Bob
	if isIdle:
		# Get sway noise
		var swayRandom : float = getSwayNoise()
		var swayRandomAdjusted = swayRandom * weaponGlobal.idleSwayAdjustment

		# Update time for sine waves
		weaponGlobal.time += delta * (swaySpeed + swayRandom)

		# Calculate random sway
		weaponGlobal.randomSwayX = sin(weaponGlobal.time * 1.5 + swayRandomAdjusted)
		weaponGlobal.randomSwayY = sin(weaponGlobal.time - swayRandomAdjusted)

	# Lerp weapon position
		if weaponGlobal.randomSwayAmount != 0:
			weaponGlobal.randomSwayX /= weaponGlobal.randomSwayAmount
			weaponGlobal.randomSwayY /= weaponGlobal.randomSwayAmount

		position.x = lerp(position.x, weaponType.position.x + (weaponGlobal.mouseMovement.x * weaponType.swayAmountPosition + weaponGlobal.randomSwayX) * delta, weaponType.swaySpeedPosition)
		position.y = lerp(position.y, weaponType.position.y + (weaponGlobal.mouseMovement.y * weaponType.swayAmountPosition + weaponGlobal.randomSwayY) * delta, weaponType.swaySpeedPosition)

		# Lerp weapon rotation
		rotation_degrees.y = lerp(rotation_degrees.y, weaponType.rotation.y - (weaponGlobal.mouseMovement.x * weaponType.swayAmountRotation) * delta, weaponType.swaySpeedRotation)
		rotation_degrees.x = lerp(rotation_degrees.x, weaponType.rotation.x - (weaponGlobal.mouseMovement.y * weaponType.swayAmountRotation) * delta, weaponType.swaySpeedRotation)
	
	#Movement bob (Not idle)
	else:
		position.x = lerp(position.x, weaponType.position.x + (weaponGlobal.mouseMovement.x * weaponType.swayAmountPosition + weaponGlobal.weaponBobAmount.x) * delta, weaponType.swaySpeedPosition)
		position.y = lerp(position.y, weaponType.position.y + (weaponGlobal.mouseMovement.y * weaponType.swayAmountPosition + weaponGlobal.weaponBobAmount.y) * delta, weaponType.swaySpeedPosition)
		# Lerp weapon rotation
		rotation_degrees.y = lerp(rotation_degrees.y, weaponType.rotation.y - (weaponGlobal.mouseMovement.x * weaponType.swayAmountRotation) * delta, weaponType.swaySpeedRotation)
		rotation_degrees.x = lerp(rotation_degrees.x, weaponType.rotation.x - (weaponGlobal.mouseMovement.y * weaponType.swayAmountRotation) * delta, weaponType.swaySpeedRotation)

#Weapon bob from movement
func weaponBob(delta, bobSpeed: float, hbobAmount: float, vbobAmount) -> void:
	weaponGlobal.time += delta
	
	weaponGlobal.weaponBobAmount.x = sin(weaponGlobal.time * bobSpeed) * hbobAmount
	weaponGlobal.weaponBobAmount.y = abs(cos(weaponGlobal.time * bobSpeed) * vbobAmount)

func getSwayNoise() -> float: 
	var noiseLocation : float = weaponGlobal.rng.randf_range(0, 1.0)
	return noiseLocation


#When left click, this function is typically called to initiate a shot
func shoot() -> void:
	#First check if the weapon is not an empty weapon, that you can shoot and you have ammo
	if weaponGlobal.clipAmmo > 0 and weaponGlobal.canShoot == true and weaponType != load("res://Weapons/Empty Weapon.tres"):
		weaponGlobal.canShoot = false  # Prevent further shooting
		weaponGlobal.cooldown_timer = weaponGlobal.time_per_shot  # Reset the cooldown timer
		#If hitscan, runs the hitscan method
		if weaponGlobal.weaponBulletPhysics == "Hitscan":
			if weaponGlobal.shotgun:
				#Make it so that this is a way of spawning not shooting
				#if either projectile or raycast it will do as below instead of just raycasts
				for i in 8:
					var hitBody = castBulletRay()
					if hitBody and hitBody.has_method("take_damage"):
						hitBody.take_damage.rpc_id(hitBody.get_multiplayer_authority(), weaponType.Damage, "bullet", Global.myCurrentTeam)  # Deal damage to the enemy
			else:
				#Single hitscan shot
				var hitBody = castBulletRay()
				if hitBody and hitBody != null:
					if hitBody.has_method("take_enemy_damage"):
						hitBody.take_enemy_damage(weaponType.Damage, "bullet")
					elif hitBody.has_method("take_damage"):
						hitBody.take_damage.rpc_id(hitBody.get_multiplayer_authority(), weaponType.Damage, "bullet", Global.myCurrentTeam)  # Deal damage to the enemy

		#If the weapon is a projectile weapon then shoot a projectile not a raycast
		if weaponGlobal.weaponBulletPhysics == "Projectile":
			var bulletInstance = weaponGlobal.weaponBulletScene.instantiate()
			var accuracyAdjustment = Vector3 (
				weaponGlobal.rng.randf_range(-weaponType.Accuracy, weaponType.Accuracy),
				weaponGlobal.rng.randf_range(-weaponType.Accuracy, weaponType.Accuracy),
				weaponGlobal.rng.randf_range(-weaponType.Accuracy, weaponType.Accuracy)
			)
			bulletInstance.global_transform = bulletSpawnPoint.global_transform
			bulletInstance.rotation += accuracyAdjustment / 100
			bulletInstance.scale = Vector3(0.25, 0.25, 0.25)
			get_tree().root.get_node("World").add_child(bulletInstance)
		
		#Global functions that always run after a shot
		#Such as updating ammo, animations and recoil
		weaponGlobal.clipAmmo -= 1
		weaponGlobal.weaponAmmoInventory[weaponGlobal.currentWeaponIndex][0] = weaponGlobal.clipAmmo
		Global.updateLabels(weaponGlobal.clipAmmo, weaponGlobal.reserveAmmo) 
		weaponAnimationPlayer.stop()
		weaponAnimationPlayer.seek(0)
		weaponAnimationPlayer.play(weaponGlobal.weaponName + "/" + "shoot", -1, 1, false)
		Global.player.cameraOffset += Vector3(weaponGlobal.verticalRecoil, weaponGlobal.horizontalRecoil, 0)
		
		#If the weapon is a bolt action, play a bolt action animation first
		if weaponGlobal.fireMode == "Bolt":
			await weaponAnimationPlayer.animation_finished
			weaponGlobal.weaponAnimationPlayer.play(weaponGlobal.weaponName + "/" + "boltCycle", -1, 1, false)
			await weaponAnimationPlayer.animation_finished
	
	#Reloads the gun if you attempt to shoot with an empty clip, but avaliable reserve ammo
		if weaponGlobal.reserveAmmo > 0 and weaponGlobal.clipAmmo == 0:
			await weaponAnimationPlayer.animation_finished
			reloadWeapon()

#Functions to create and test a raycast for hitting another player or enemy
func castBulletRay():
	#The variables below create a temporary ray cast, along with accuracy modifier
	var accuracyAdjustment = Vector3 (
				weaponGlobal.rng.randf_range(-weaponType.Accuracy, weaponType.Accuracy),
				weaponGlobal.rng.randf_range(-weaponType.Accuracy, weaponType.Accuracy),
				weaponGlobal.rng.randf_range(-weaponType.Accuracy, weaponType.Accuracy)
				)
	var camera = Global.player.CAMERA_CONTROLLER
	var spaceState = camera.get_world_3d().direct_space_state
	var screenCenter = get_viewport().size / 2
	var origin = camera.project_ray_origin(screenCenter)
	var endpoint = origin + camera.project_ray_normal(screenCenter) * 1000 + accuracyAdjustment * 10
	var query = PhysicsRayQueryParameters3D.create(origin, endpoint)
	query.collide_with_bodies = true
	var result = spaceState.intersect_ray(query)
	var hitBody = result.get("collider")  # Get the object that was hit
	return hitBody



#This runs when you reload a weapon, usually from pressing "r"
func reloadWeapon():
	#Disallows shooting and sets cooldown to a dummy value to prevent shooting
	weaponGlobal.canShoot = false
	weaponGlobal.cooldown_timer = 100
	
	#This mode reloads the weapon with individual bullets/shells one at a time
	#Controls animation and reloading
	if weaponGlobal.reloadMode == "Shell":
		var ammoNeeded = weaponGlobal.maxClipAmmo - weaponGlobal.clipAmmo
		weaponAnimationPlayer.play(weaponGlobal.weaponName + "/" + "startReload", -1, 1, false)
		await weaponAnimationPlayer.animation_finished
		for n in ammoNeeded:
			weaponAnimationPlayer.play(weaponGlobal.weaponName + "/" + "shellReload", -1, 1, false)
			weaponGlobal.reserveAmmo -= 1
			weaponGlobal.clipAmmo += 1
			await weaponAnimationPlayer.animation_finished
		weaponAnimationPlayer.play(weaponGlobal.weaponName + "/" + "finishReload", -1, 1, false)
		
	#Otherwise just play a standard reload animation, usually a magazine.
	else:
		if weaponGlobal.clipAmmo > 0:
			weaponAnimationPlayer.play(weaponGlobal.weaponName + "/" + "fullReload", -1, 1, false)
			await weaponAnimationPlayer.animation_finished
		else:
			weaponAnimationPlayer.play(weaponGlobal.weaponName + "/" + "emptyReload", -1, 1, false)
			await weaponAnimationPlayer.animation_finished
		var ammoNeeded = weaponGlobal.maxClipAmmo - weaponGlobal.clipAmmo
		
		#Changes the ammo internally
		if weaponGlobal.reserveAmmo >= ammoNeeded:
			weaponGlobal.reserveAmmo -= ammoNeeded
			weaponGlobal.clipAmmo = weaponGlobal.maxClipAmmo
		else:
			weaponGlobal.clipAmmo += weaponGlobal.reserveAmmo
			weaponGlobal.reserveAmmo = 0


	#Updates the UI to the player and ammo internally
	Global.updateLabels(weaponGlobal.clipAmmo, weaponGlobal.reserveAmmo)
	weaponGlobal.weaponAmmoInventory[weaponGlobal.currentWeaponIndex] = [weaponGlobal.clipAmmo, weaponGlobal.reserveAmmo]
	weaponGlobal.canShoot = true
	weaponGlobal.cooldown_timer = 0


func _process(delta: float) -> void:
	#This decreases the shooting cooldown timer
	#Additional functionality for auto weapons
	if !Engine.is_editor_hint():
		if weaponGlobal.cooldown_timer > 0:
			weaponGlobal.cooldown_timer -= delta  # Decrease the cooldown timer
		else:
			weaponGlobal.canShoot = true  # Allow shooting once the cooldown ends
			if weaponGlobal.fireMode == "Auto" and Input.is_action_pressed("shoot"):
				shoot()

		if Input.is_action_just_pressed("reload") and weaponGlobal.clipAmmo != weaponGlobal.maxClipAmmo:
			reloadWeapon()

#this is an old function for bulletholes on the world
#Works perfectly fine but bulletholes have slight visual issues.
func removeHitMark(Instance):
	await get_tree().create_timer(weaponGlobal.rng.randi_range(4, 12)).timeout
	Instance.queue_free()


#This runs when you or the system attempts you drop a weapon from you
func dropWeapon():
	#Only runs if you are holding a weapon
	if !Engine.is_editor_hint():
		if weaponType != load("res://Weapons/Empty Weapon.tres"):
			#Create references to the current weapons stats
			var currentWeapon = weaponGlobal.weaponInventory[weaponGlobal.currentWeaponIndex]
			var currentClip = weaponGlobal.clipAmmo
			var currentReserve = weaponGlobal.reserveAmmo
			#Dropped weapon instance and velocity, adds it to the tree and calls
			#functions on the dropped weapon to load the correct stats
			#Loading the correct stats on the weapon drop allows a dropped weapon to retain stats
			var dropInstance = weaponDrop.instantiate()
			var dropVel = Vector3(0,0,0)
			get_tree().root.get_node("World").add_child(dropInstance)
			dropInstance.global_position = bulletSpawnPoint.global_position
			dropInstance.setWeapon(currentWeapon)
			dropInstance.setModel(currentWeapon)
			dropInstance.setTeam(Global.myCurrentTeam)
			dropInstance.parseAmmo(currentClip, currentReserve)
			weaponGlobal.inventoryWeight -= weaponType.weight
			
			dropVel = -Global.playerCamera.global_transform.basis.z.normalized() * (Global.player.velocity.length() + 12)
			dropInstance.changeVel(dropVel)
			
			#Fall back incase after you drop the weapon is not an empty weapon
			if weaponType != load("res://Weapons/Empty Weapon.tres"):
				weaponGlobal.weaponInventory[weaponGlobal.currentWeaponIndex] = "res://Weapons/Empty Weapon.tres"
				loadWeapon()

			#Replicates the drop to the other players on the server
			rpc("replicateDroppedWeapon", str(currentWeapon), currentClip, currentReserve, dropInstance.global_position, dropVel, Global.myCurrentTeam)

#This function is for when another player drops their weapon
#This creates a version on your side that has the same stats
@rpc("any_peer")
func replicateDroppedWeapon(weapon, clip, reserve, dropPos, dropVel, team):
	var dropInstance = weaponDrop.instantiate()
	get_tree().root.get_node("World").add_child(dropInstance)
	dropInstance.global_position = dropPos
	dropInstance.setWeapon(weapon)
	dropInstance.setTeam(team)
	dropInstance.setModel(weapon)
	dropInstance.parseAmmo(clip, reserve)
	dropInstance.changeVel(dropVel)


func replicateWeaponVisual(weaponPath):
	var replicatedWeapon = load(weaponPath)
	weaponMesh.mesh = replicatedWeapon.mesh
	weaponMagazine.mesh = replicatedWeapon.magazine
	weaponBolt.mesh = replicatedWeapon.bolt
	weaponShadow.mesh = replicatedWeapon.mesh
	#Gun Orientation
	position = replicatedWeapon.position
	rotation_degrees = replicatedWeapon.rotation
	scale = replicatedWeapon.scale
	#Magazine Orientation
	weaponMagazine.position = replicatedWeapon.magazinePosition
	weaponMagazine.rotation_degrees = replicatedWeapon.magazineRotation
	weaponMagazine.scale = replicatedWeapon.magazineScale
	#Bolt Orientation
	weaponBolt.position = replicatedWeapon.boltPosition
	weaponBolt.rotation_degrees = replicatedWeapon.boltRotation
	weaponBolt.scale = replicatedWeapon.boltScale
	weaponShadow.visible = replicatedWeapon.shadow
#This function is for adding ammo to the player, such as a ammo pickup
func addAmmo(clipAdd, reserveAdd):
	#Method of adding ammo
	var ammoNeeded = weaponGlobal.maxClipAmmo - weaponGlobal.clipAmmo
	
	#Checks how much ammo you need, if the amount you add is over the needed, cap it to max
	if clipAdd > ammoNeeded:
		weaponGlobal.clipAmmo = weaponGlobal.maxClipAmmo
	else:
		#Adds ammo normally
		weaponGlobal.clipAmmo += clipAdd

	#Updates ammo internally and labels
	weaponGlobal.reserveAmmo += reserveAdd
	Global.clipLabel.text = str(weaponGlobal.clipAmmo)
	Global.reserveLabel.text = str(weaponGlobal.reserveAmmo)

#Applys shader to prevent weapon clipping
func apply_clip_and_fov_shader_to_view_model(node3d : Node3D, fov_or_negative_for_unchanged = -1.0):
	var all_mesh_instances = node3d.find_children("*", "MeshInstance3D")
	if node3d is MeshInstance3D:
		all_mesh_instances.push_back(node3d)
	for mesh_instance in all_mesh_instances:
		var mesh = mesh_instance.mesh
		# Important to turn shadow casting off for view model or will cause issues with both
		# view model, casting shadows on itself once unclipped, & also will look weird casting on world.
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh != null:
			for surface_idx in mesh.get_surface_count():
				var base_mat = mesh.surface_get_material(surface_idx)
				if not base_mat is BaseMaterial3D: continue
				var weapon_shader_material := ShaderMaterial.new()
				weapon_shader_material.shader = load("res://Shaders/weaponClip.gdshader")
				weapon_shader_material.set_shader_parameter("texture_albedo", base_mat.albedo_texture)
				weapon_shader_material.set_shader_parameter("texture_metallic", base_mat.metallic_texture)
				weapon_shader_material.set_shader_parameter("texture_roughness", base_mat.roughness_texture)
				weapon_shader_material.set_shader_parameter("texture_normal", base_mat.normal_texture)
				weapon_shader_material.set_shader_parameter("albedo", base_mat.albedo_color)
				weapon_shader_material.set_shader_parameter("metallic", base_mat.metallic)
				weapon_shader_material.set_shader_parameter("specular", base_mat.metallic_specular)
				weapon_shader_material.set_shader_parameter("roughness", base_mat.roughness)
				weapon_shader_material.set_shader_parameter("viewmodel_fov", fov_or_negative_for_unchanged)
				var tex_channels = { 0: Vector4(1., 0., 0., 0.), 1: Vector4(0., 1., 0., 0.), 2: Vector4(0., 0., 1., 0.), 3: Vector4(1., 0., 0., 1.), 4: Vector4() }
				weapon_shader_material.set_shader_parameter("metallic_texture_channel", tex_channels[base_mat.metallic_texture_channel])
				mesh_instance.set_surface_override_material(surface_idx, weapon_shader_material)

#func _physics_process(delta) -> void:

#✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅
#Certified definetly good script, as shown by the emoji
