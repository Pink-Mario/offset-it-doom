extends Control

# --- Dragging state ---
var dragging: bool = false
var can_drag: bool = false
var drag_offset: Vector2 = Vector2.ZERO

# --- Sprite offset ---
var sprite_offset: Vector2 = Vector2.ZERO

# --- Constants ---
const FULL_SIZE: Vector2 = Vector2(320, 200)
const ANCHOR_POINT: Vector2 = Vector2.ZERO  # Top-left corner reference

# --- Node references ---
@onready var sub_viewport_container: SubViewportContainer = $SubViewportContainer
@onready var background: ColorRect = $Background
@onready var sprite_editor_space: Control = $SubViewportContainer/SubViewport/SpriteEditorSpace
@onready var weapon_sprite: TextureRect = $SubViewportContainer/SubViewport/SpriteEditorSpace/WeaponSprite

@onready var offset_data_container: HBoxContainer = $OffsetDataContainer
@onready var sprite_offset_x_box: SpinBox = $OffsetDataContainer/SpriteOffsetX
@onready var sprite_offset_y_box: SpinBox = $OffsetDataContainer/SpriteOffsetY
@onready var file_dialog: FileDialog = $FileDialog

# --- Ready ---
func _ready() -> void:
	update_weapon_position()

# --- Mouse hover ---
func _on_weapon_sprite_mouse_entered() -> void:
	can_drag = true

func _on_weapon_sprite_mouse_exited() -> void:
	can_drag = false

# --- Input handling ---
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and can_drag:
			dragging = true
			drag_offset = get_viewport_mouse_in_subviewport() - (ANCHOR_POINT - sprite_offset)
		else:
			dragging = false

	elif event is InputEventMouseMotion and dragging:
		var mouse_pos = get_viewport_mouse_in_subviewport()
		sprite_offset = ANCHOR_POINT - (mouse_pos - drag_offset)
		sprite_offset = sprite_offset.round()
		update_weapon_position()

# --- Update sprite position and SpinBoxes ---
func update_weapon_position() -> void:
	weapon_sprite.position = ANCHOR_POINT - sprite_offset
	sprite_offset_x_box.value = sprite_offset.x
	sprite_offset_y_box.value = sprite_offset.y

# --- SpinBox callbacks ---
func _on_sprite_offset_x_value_changed(value: float) -> void:
	sprite_offset.x = value
	update_weapon_position()

func _on_sprite_offset_y_value_changed(value: float) -> void:
	sprite_offset.y = value
	update_weapon_position()

# --- Utility functions ---
func get_viewport_mouse_in_subviewport() -> Vector2:
	var local_mouse = sub_viewport_container.get_local_mouse_position()
	var scale = sub_viewport_container.size / FULL_SIZE
	return local_mouse / scale

func round_offsets() -> void:
	sprite_offset = sprite_offset.round()

func import_weapon_sprite(path: String) -> void:
	var img = Image.new()
	var err = img.load(path)
	if err != OK:
		push_error("Failed to load image: %s" % path)
		return
	
	var tex = ImageTexture.new()
	tex.create_from_image(img)
	
	weapon_sprite.texture = tex
	weapon_sprite.size = tex.get_size()  # Important!
	weapon_sprite.stretch_mode = TextureRect.STRETCH_KEEP
	
	sprite_offset = Vector2.ZERO
	update_weapon_position()
	
func _on_import_button_pressed() -> void:
	file_dialog.popup()

func _on_file_dialog_file_selected(path: String) -> void:
	import_weapon_sprite(path)

func _on_set_origin_button_pressed() -> void:
	pass # Replace with function body.
