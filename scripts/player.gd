extends Node3D

class_name Player

signal target_changed(target_node)

# Player properties
var hp: int
var inventory: Array = []
var power: int = 1
var isHandcuffed: bool = false
var current_target_index: int = 0
var targets: Array = []
var duplicateTargets: Array = []
var is_my_turn: bool = false
var game_state
var selectingTarget: bool = false
var pendingUpgrade: Upgrade = null

# Inventory mode
var is_inventory_mode: bool = false
var inventory_ui: InventoryUI

# UI References
@onready var target_label: Label = $CanvasLayer/TopHUDContainer/TargetRow/TargetValuePanel/TargetValueContainer/TargetLabel
@onready var target_label_static: Label = $CanvasLayer/TopHUDContainer/TargetRow/TargetLabelStatic
@onready var target_value_panel: PanelContainer = $CanvasLayer/TopHUDContainer/TargetRow/TargetValuePanel
@onready var left_arrow: Label = $CanvasLayer/TopHUDContainer/TargetRow/TargetValuePanel/TargetValueContainer/LeftArrow
@onready var right_arrow: Label = $CanvasLayer/TopHUDContainer/TargetRow/TargetValuePanel/TargetValueContainer/RightArrow

@onready var currRound: Label = $CanvasLayer/TopHUDContainer/RoundRow/RoundValuePanel/RoundValueContainer/RoundLabel
@onready var round_label_static: Label = $CanvasLayer/TopHUDContainer/RoundRow/RoundLabelStatic
@onready var round_value_panel: PanelContainer = $CanvasLayer/TopHUDContainer/RoundRow/RoundValuePanel

@onready var bulletCounts: Label = $CanvasLayer/TopHUDContainer/BulletRow/BulletValuePanel/BulletValueContainer/BulletLabel
@onready var bullet_label_static: Label = $CanvasLayer/TopHUDContainer/BulletRow/BulletLabelStatic
@onready var bullet_value_panel: PanelContainer = $CanvasLayer/TopHUDContainer/BulletRow/BulletValuePanel

@onready var inventory_container: HBoxContainer = $CanvasLayer/InventoryContainer
@onready var slot_container: HBoxContainer = $CanvasLayer/InventoryContainer/SlotContainer
@onready var left_scroll_indicator: Label = $CanvasLayer/InventoryContainer/LeftArrow
@onready var right_scroll_indicator: Label = $CanvasLayer/InventoryContainer/RightArrow

@onready var game_manager: Node = get_node("../GameManager")
@onready var gun: Node3D = $Gun
@onready var animation_player: AnimationPlayer = $Gun/AnimationPlayer
@onready var health_jug = $HealthJug

func _init(_name: String = "Player", _hp: int = 3):
	name = _name
	hp = _hp
	inventory = []

func _ready():
	health_jug.create(game_manager.maxHP)
	
	# Initialize inventory UI
	inventory_ui = InventoryUI.new()
	inventory_ui.initialize(slot_container, left_scroll_indicator, right_scroll_indicator)
	
	# Setup HUD styling
	setup_hud_styling()
	
	# Hide target display initially
	target_label.visible = false
	left_arrow.visible = false
	right_arrow.visible = false
	
func setup_hud_styling():
	# Colors
	var dark_red = Color(0.545, 0, 0)  # #8B0000
	var light_red = Color(1.0, 0.714, 0.757)  # #FFB6C1
	var white = Color(1.0, 1.0, 1.0)
	var black = Color(0, 0, 0)
	
	# Target Row Styling
	target_label_static.add_theme_color_override("font_color", white)
	
	var target_value_style = StyleBoxFlat.new()
	target_value_style.bg_color = light_red
	target_value_panel.add_theme_stylebox_override("panel", target_value_style)
	target_label.add_theme_color_override("font_color", black)
	left_arrow.add_theme_color_override("font_color", black)
	right_arrow.add_theme_color_override("font_color", black)
	
	# Round Row Styling
	var round_value_style = StyleBoxFlat.new()
	round_value_style.bg_color = light_red
	round_value_panel.add_theme_stylebox_override("panel", round_value_style)
	round_label_static.add_theme_color_override("font_color", white)
	currRound.add_theme_color_override("font_color", black)
	
	# Bullet Row Styling
	var bullet_value_style = StyleBoxFlat.new()
	bullet_value_style.bg_color = light_red
	bullet_value_panel.add_theme_stylebox_override("panel", bullet_value_style)
	bullet_label_static.add_theme_color_override("font_color", white)
	bulletCounts.add_theme_color_override("font_color", black)
	
	# Scroll indicators styling
	left_scroll_indicator.add_theme_color_override("font_color", white)
	left_scroll_indicator.text = "◀"
	right_scroll_indicator.add_theme_color_override("font_color", white)
	right_scroll_indicator.text = "▶"
	
func _process(delta):
	if not is_my_turn:
		return
	
	# Toggle inventory mode with Up and Down keys
	if is_inventory_mode and Input.is_action_just_pressed("ui_up"):
		toggle_inventory_mode()
		return
	if (not is_inventory_mode) and Input.is_action_just_pressed("ui_down"):
		toggle_inventory_mode()
		return

	# Handle inventory navigation
	if is_inventory_mode:
		if Input.is_action_just_pressed("ui_left"):
			inventory_ui.navigate_left(inventory)
		elif Input.is_action_just_pressed("ui_right"):
			inventory_ui.navigate_right(inventory)
		elif Input.is_action_just_pressed("ui_select"):
			use_selected_inventory_item()
		return
	
	# Handle target navigation (original logic)
	if Input.is_action_just_pressed("ui_left"):
		current_target_index = (current_target_index - 1 + targets.size()) % targets.size()
		update_target()
	elif Input.is_action_just_pressed("ui_right"):
		current_target_index = (current_target_index + 1) % targets.size()
		update_target()
	elif Input.is_action_just_pressed("ui_select"):
		if targets.size() == 0:
			return
		var target = targets[current_target_index]
		
		if selectingTarget:
			selectingTarget = false
			targets = duplicateTargets.duplicate()
			game_manager.useUpgrade(pendingUpgrade, self, target)
			pendingUpgrade = null
			return
			
		if game_state.isUpgradeRound:
			if target is Upgrade:
				is_my_turn = false
				call_deferred("pickUpgradeDeferred", target)
		else:
			if target is Player:
				is_my_turn = false
				call_deferred("shootDeferred", target)

func toggle_inventory_mode():
	is_inventory_mode = !is_inventory_mode
	inventory_ui.toggle_active()
	
	if is_inventory_mode:
		# Hide target navigation arrows
		left_arrow.visible = false
		right_arrow.visible = false
	else:
		# Show target navigation arrows if we have targets
		if targets.size() > 1:
			left_arrow.visible = true
			right_arrow.visible = true

func use_selected_inventory_item():
	var selected_upgrade = inventory_ui.get_selected_upgrade(inventory)
	
	if selected_upgrade == null:
		return
	
	# Check if upgrade requires target selection (like handcuff)
	if selected_upgrade.upgrade_type == Upgrade.UpgradeType.handcuff:
		selectingTarget = true
		pendingUpgrade = selected_upgrade
		duplicateTargets = targets.duplicate()
		targets = game_state.alivePlayers.duplicate()
		targets.erase(self)
		current_target_index = 0
		
		# Exit inventory mode to select target
		is_inventory_mode = false
		inventory_ui.toggle_active()
		
		update_target()
		return
	
	# Use the upgrade immediately
	game_manager.useUpgrade(selected_upgrade, self, self)
	inventory_ui.update_display(inventory)

func pickUpgradeDeferred(target: Upgrade):
	game_manager.pickUpUpgrade(self, target)

func shootDeferred(target: Player):
	game_manager.shootPlayer(self, target)
	
func update_target():
	if targets.size() > 0:
		var target = targets[current_target_index]
		target_changed.emit(target)
		if target is Player:
			if target == self:
				animation_player.play("aim_self")
			else:
				animation_player.play("aim_forward")
			target_label.set_text(target.name)
		elif target is Upgrade:
			animation_player.play("aim_forward")
			target_label.set_text(Upgrade.UpgradeType.keys()[target.upgrade_type])
		
		# Show arrows if multiple targets
		if targets.size() > 1 and not is_inventory_mode:
			left_arrow.visible = true
			right_arrow.visible = true
		else:
			left_arrow.visible = false
			right_arrow.visible = false
	else:
		animation_player.play("aim_forward")
		left_arrow.visible = false
		right_arrow.visible = false

func onTurnEnd(new_game_state: GameState, current_player_index: int):
	game_state = new_game_state
	currRound.text = "Round: " + str(game_state.currRoundIndex + 1) + " Turn: " + str(game_state.currTurnIndex + 1)
	bulletCounts.text = "Live: " + str(game_state.realCount) + " | Blank: " + str(game_state.blanksCount)
	
	is_my_turn = (game_state.alivePlayers[current_player_index] == self)
	target_label.visible = is_my_turn
	
	if !targets.is_empty():
		current_target_index = 0
	else: 
		print("Something went wrong")
	
	if is_my_turn:
		if game_state.isUpgradeRound:
			targets = remove_nulls_from_array(game_state.upgradesOnTable)
			if targets.size() == 0:
				targets = remove_nulls_from_array(game_state.alivePlayers)
		else:
			targets = remove_nulls_from_array(game_state.alivePlayers)
		update_target()
		
		# Update inventory display
		inventory_ui.update_display(inventory)

# Inventory management
func addInventory(upgrade: Upgrade) -> void:
	inventory.append(upgrade)
	upgrade.reparent(self)
	upgrade.position = health_jug.position
	upgrade.position.z += 3
	
	# Update inventory UI
	if inventory_ui:
		inventory_ui.update_display(inventory)

func removeInventory(upgrade: Upgrade) -> bool:
	if upgrade in inventory:
		inventory.erase(upgrade)
		if inventory_ui:
			inventory_ui.update_display(inventory)
		return true
	return false

# Check if player has a specific upgrade
func hasUpgrade(upgrade: Upgrade) -> bool:
	return upgrade in inventory

# Apply damage to the player
func takeDamage(amount: int) -> void:
	for i in amount:
		health_jug.drink()
	hp -= amount
	if hp < 0:
		hp = 0

# Heal the player
func heal(amount: int, max_hp: int) -> void:
	for i in amount:
		health_jug.refill()
	hp += amount
	if hp > max_hp:
		hp = max_hp

func isAlive() -> bool:
	return hp > 0

func remove_nulls_from_array(original_array: Array) -> Array:
	var filtered_array = []
	for item in original_array:
		if item != null:
			filtered_array.append(item)
	return filtered_array
