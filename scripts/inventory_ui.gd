extends Control

class_name InventoryUI

# Visual elements
var inventory_slots: Array[PanelContainer] = []
var slot_icons: Array[TextureRect] = []
var slot_container: HBoxContainer
var left_scroll_indicator: Label
var right_scroll_indicator: Label

# State
var is_active: bool = false
var selected_slot_index: int = 0
var inventory_window_start: int = 0
const WINDOW_SIZE: int = 10
const SLOT_SIZE: int = 32
const DEFAULT_BORDER_WIDTH: int = 2
const HIGHLIGHTED_BORDER_WIDTH: int = 8

# Colors
const EMPTY_SLOT_COLOR: Color = Color(1.0, 0.784, 0.784, 0.8)  # #ffc8c8cc
const DEFAULT_BORDER_COLOR: Color = Color(0.8, 0.8, 0.8, 1.0)  # Light grey
const HIGHLIGHT_BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)  # Bright white

# Icon paths
const UPGRADE_ICONS = {
	Upgrade.UpgradeType.cigarette: "res://assets/icons/cigarette.png",
	Upgrade.UpgradeType.beer: "res://assets/icons/beer.png",
	Upgrade.UpgradeType.magGlass: "res://assets/icons/mag_glass.png",
	Upgrade.UpgradeType.handcuff: "res://assets/icons/handcuff.png",
	Upgrade.UpgradeType.expiredMed: "res://assets/icons/powerup.png",
	Upgrade.UpgradeType.inverter: "res://assets/icons/powerup.png",
	Upgrade.UpgradeType.burnerPhone: "res://assets/icons/powerup.png",
	Upgrade.UpgradeType.handSaw: "res://assets/icons/powerup.png",
	Upgrade.UpgradeType.adrenaline: "res://assets/icons/powerup.png",
	Upgrade.UpgradeType.disableUpgrade: "res://assets/icons/powerup.png",
	Upgrade.UpgradeType.unoRev: "res://assets/icons/powerup.png",
	Upgrade.UpgradeType.wildCard: "res://assets/icons/powerup.png"
}

func initialize(parent_container: HBoxContainer, left_indicator: Label, right_indicator: Label) -> void:
	slot_container = parent_container
	left_scroll_indicator = left_indicator
	right_scroll_indicator = right_indicator
	
	# Create 10 inventory slots
	for i in range(WINDOW_SIZE):
		var slot = PanelContainer.new()
		
		# Create custom style for the slot
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = EMPTY_SLOT_COLOR
		style_box.border_color = DEFAULT_BORDER_COLOR
		style_box.set_border_width_all(DEFAULT_BORDER_WIDTH)
		slot.add_theme_stylebox_override("panel", style_box)
		
		# Set minimum size
		slot.custom_minimum_size = Vector2(SLOT_SIZE + DEFAULT_BORDER_WIDTH * 2, SLOT_SIZE + DEFAULT_BORDER_WIDTH * 2)
		
		# Add icon texture rect
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(icon)
		
		slot_container.add_child(slot)
		inventory_slots.append(slot)
		slot_icons.append(icon)
	
	# Hide scroll indicators initially
	left_scroll_indicator.visible = false
	right_scroll_indicator.visible = false

func toggle_active() -> void:
	is_active = !is_active
	
	if is_active:
		selected_slot_index = 0
		highlight_slot(0)
	else:
		# Remove all highlights
		for i in range(WINDOW_SIZE):
			reset_slot_border(i)

func navigate_left(player_inventory: Array) -> void:
	if not is_active:
		return
	
	# Remove current highlight
	reset_slot_border(selected_slot_index)
	
	# Move selection left
	selected_slot_index -= 1
	
	# Handle sliding window
	if selected_slot_index < 0:
		if inventory_window_start > 0:
			inventory_window_start -= 1
			selected_slot_index = 0
		else:
			# Wrap to the end
			if player_inventory.size() > WINDOW_SIZE:
				inventory_window_start = player_inventory.size() - WINDOW_SIZE
				selected_slot_index = WINDOW_SIZE - 1
			else:
				selected_slot_index = player_inventory.size() - 1 if player_inventory.size() > 0 else 0
	
	highlight_slot(selected_slot_index)
	update_display(player_inventory)

func navigate_right(player_inventory: Array) -> void:
	if not is_active:
		return
	
	# Remove current highlight
	reset_slot_border(selected_slot_index)
	
	# Move selection right
	selected_slot_index += 1
	
	# Handle sliding window
	var visible_items = min(WINDOW_SIZE, player_inventory.size() - inventory_window_start)
	
	if selected_slot_index >= visible_items:
		if inventory_window_start + WINDOW_SIZE < player_inventory.size():
			inventory_window_start += 1
			selected_slot_index = WINDOW_SIZE - 1
		else:
			# Wrap to the beginning
			inventory_window_start = 0
			selected_slot_index = 0
	
	highlight_slot(selected_slot_index)
	update_display(player_inventory)

func update_display(player_inventory: Array) -> void:
	# Update scroll indicators
	left_scroll_indicator.visible = inventory_window_start > 0
	right_scroll_indicator.visible = inventory_window_start + WINDOW_SIZE < player_inventory.size()
	
	# Update each slot
	for i in range(WINDOW_SIZE):
		var actual_index = inventory_window_start + i
		
		if actual_index < player_inventory.size() and player_inventory[actual_index] != null:
			# Show the item icon
			var upgrade = player_inventory[actual_index] as Upgrade
			if upgrade and UPGRADE_ICONS.has(upgrade.upgrade_type):
				var icon_path = UPGRADE_ICONS[upgrade.upgrade_type]
				if ResourceLoader.exists(icon_path):
					slot_icons[i].texture = load(icon_path)
				else:
					slot_icons[i].texture = null
			else:
				slot_icons[i].texture = null
		else:
			# Empty slot
			slot_icons[i].texture = null
	
	# Reapply highlight if active
	if is_active:
		highlight_slot(selected_slot_index)

func highlight_slot(index: int) -> void:
	if index < 0 or index >= WINDOW_SIZE:
		return
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = EMPTY_SLOT_COLOR
	style_box.border_color = HIGHLIGHT_BORDER_COLOR
	style_box.set_border_width_all(HIGHLIGHTED_BORDER_WIDTH)
	
	inventory_slots[index].add_theme_stylebox_override("panel", style_box)
	inventory_slots[index].custom_minimum_size = Vector2(SLOT_SIZE + HIGHLIGHTED_BORDER_WIDTH * 2, SLOT_SIZE + HIGHLIGHTED_BORDER_WIDTH * 2)

func reset_slot_border(index: int) -> void:
	if index < 0 or index >= WINDOW_SIZE:
		return
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = EMPTY_SLOT_COLOR
	style_box.border_color = DEFAULT_BORDER_COLOR
	style_box.set_border_width_all(DEFAULT_BORDER_WIDTH)
	
	inventory_slots[index].add_theme_stylebox_override("panel", style_box)
	inventory_slots[index].custom_minimum_size = Vector2(SLOT_SIZE + DEFAULT_BORDER_WIDTH * 2, SLOT_SIZE + DEFAULT_BORDER_WIDTH * 2)

func get_selected_upgrade(player_inventory: Array) -> Upgrade:
	if not is_active:
		return null
	
	var actual_index = inventory_window_start + selected_slot_index
	
	if actual_index >= 0 and actual_index < player_inventory.size():
		return player_inventory[actual_index]
	
	return null

func reset_window() -> void:
	inventory_window_start = 0
	selected_slot_index = 0
	is_active = false
	
	for i in range(WINDOW_SIZE):
		reset_slot_border(i)
