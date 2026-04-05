extends Control

var dragging: bool = false
var can_drag: bool = false
var drag_offset: Vector2 = Vector2.ZERO

var sprite_offset: Vector2 = Vector2(-184, -94)

const FULL_SIZE: Vector2 = Vector2(640, 400)
const ANCHOR_POINT: Vector2 = Vector2(160, 100)
const DEFAULT_OFFSET: Vector2 = Vector2(0, 32)
const DEFAULT_SPRITE_OFFSET: Vector2 = Vector2(-184, -94)
const TEXTURE_GHOST = preload("res://scenes/texture_ghost_image.tscn")
const TEXTURE_EHANCE = preload("res://scenes/texture_enhance.tscn")
const ANIM_CELL = preload("res://scenes/anim_cell.tscn")
const CURVE_POINT_LINE = preload("res://scenes/curve_point_line.tscn")

@onready var sub_viewport_container: SubViewportContainer = $SubViewportContainer
@onready var background: ColorRect = $Background
@onready var sprite_editor_space: Control = $SubViewportContainer/SubViewport/SpriteEditorSpace
@onready var weapon_sprite: TextureRect = $SubViewportContainer/SubViewport/SpriteEditorSpace/WeaponSprite

@onready var offset_data_container: HBoxContainer = $OffsetDataContainer
@onready var sprite_offset_x_box: SpinBox = $OffsetDataContainer/SpriteOffsetX
@onready var sprite_offset_y_box: SpinBox = $OffsetDataContainer/SpriteOffsetY
@onready var file_dialog: FileDialog = $FileDialog
@onready var offset_calls_per: SpinBox = $OffsetItDisplay/OffsetCallsPer
@onready var offset_call_list: TextEdit = $OffsetItDisplay/OffsetCallList
@onready var set_origin_button: Button = $ButtonHBox/SetOriginButton
@onready var import_button: Button = $ButtonHBox/ImportButton
@onready var play_button: Button = $ButtonHBox/PlayButton
@onready var playback_timer: Timer = $PlaybackTimer
@onready var offset_it_slider: HSlider = $OffsetItSlider

@onready var cell_container_g: GridContainer = $AnimCellScroll/CellContainerP/CellContainerG

var origin_set = false
var op_start := Vector2.ZERO
var drag_start_offset := Vector2.ZERO
var imported_sprite_name: String = ""

var curve_points: Array[Vector2] = [] 
var curve_line: Line2D = null
var curve_point_visuals: Array[Node2D] = []

class CellData:
	var sprite_path: String = ""
	var sprite_name: String = ""
	var sprite_texture: Texture2D = null
	var sprite_size: Vector2 = Vector2.ZERO
	var sprite_offset: Vector2 = Vector2.ZERO
	var reference_offset: Vector2 = Vector2.ZERO
	var cell_ui: AnimCell = null
	var ghost_node: TextureRect = null
	
	func _init():
		pass

var animation_cells: Array[CellData] = []
var active_cell_index: int = -1

var is_playing: bool = false
var current_frame_index: int = 0
var playback_speed: float = 0.03

var button_pulse_tween: Tween

var imported_sprite_path = "":
	set(value):
		imported_sprite_path = value
		print(imported_sprite_path)

var last_imported_sprite_name: String = ""

func _ready() -> void:
	file_dialog.filters = PackedStringArray([
		"*.png",
		"*.jpeg",
		"*.bmp",
		"*.tga",
		"*.webp"
	])
	
	playback_timer.wait_time = playback_speed
	playback_timer.timeout.connect(_on_playback_tick)
	update_weapon_position()
	create_default_cell()

func create_default_cell() -> void:
	var default_cell = CellData.new()
	var grab_offset = read_grab_offset(imported_sprite_path)
	
	if weapon_sprite.texture:
		default_cell.sprite_texture = weapon_sprite.texture
		default_cell.sprite_name = imported_sprite_name
		default_cell.sprite_size = weapon_sprite.size
	
	default_cell.sprite_offset = grab_offset
	default_cell.reference_offset = grab_offset
	
	animation_cells.append(default_cell)
	add_cell_ui(0)
	create_ghost_for_cell(0)
	update_slider_range()

func _on_weapon_sprite_mouse_entered() -> void:
	can_drag = true

func _on_weapon_sprite_mouse_exited() -> void:
	can_drag = false


func _input(event: InputEvent) -> void:
	if is_playing:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and can_drag:
				dragging = true
				drag_offset = get_viewport_mouse_in_subviewport() - (ANCHOR_POINT - sprite_offset)
				
				if origin_set:
					drag_start_offset = sprite_offset
					curve_points.clear()
					curve_points.append(ANCHOR_POINT - drag_start_offset)
					create_curve_line()
					
			else:
				if dragging:
					dragging = false
					if origin_set:
						curve_points.append(weapon_sprite.position)
						update_curve_line()
						
						create_cell_from_drag()
						origin_set = false
						stop_button_pulse()
						play_button.disabled = false
						
						clear_curve_visual()
					else:
						regenerate_decorate_code()
					kill_invalid_cells()
						
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed and dragging and origin_set:
				var current_pos = weapon_sprite.position
				curve_points.append(current_pos)
				update_curve_line()
				create_curve_point_visual(current_pos)
				print("Added curve point at: %s" % current_pos)

	elif event is InputEventMouseMotion and dragging:
		var mouse_pos = get_viewport_mouse_in_subviewport()
		sprite_offset = ANCHOR_POINT - (mouse_pos - drag_offset)
		sprite_offset = sprite_offset.round()
		update_weapon_position()
		
		if not origin_set and active_cell_index >= 0 and active_cell_index < animation_cells.size():
			animation_cells[active_cell_index].sprite_offset = sprite_offset
			update_cell_ghost(active_cell_index)
			
		if origin_set and curve_line:
			update_curve_line_preview(weapon_sprite.position)

func update_weapon_position() -> void:
	weapon_sprite.position = ANCHOR_POINT - sprite_offset
	sprite_offset_x_box.value = sprite_offset.x
	sprite_offset_y_box.value = sprite_offset.y

func _on_sprite_offset_x_value_changed(value: float) -> void:
	if is_playing:
		return
	sprite_offset.x = value
	update_weapon_position()
	
	if active_cell_index >= 0 and active_cell_index < animation_cells.size():
		animation_cells[active_cell_index].sprite_offset = sprite_offset
		update_cell_ghost(active_cell_index)
		regenerate_decorate_code()
	kill_invalid_cells()

func _on_sprite_offset_y_value_changed(value: float) -> void:
	if is_playing:
		return
	sprite_offset.y = value
	update_weapon_position()
	
	if active_cell_index >= 0 and active_cell_index < animation_cells.size():
		animation_cells[active_cell_index].sprite_offset = sprite_offset
		update_cell_ghost(active_cell_index)
		regenerate_decorate_code()
	kill_invalid_cells()

func get_viewport_mouse_in_subviewport() -> Vector2:
	var local_mouse = sub_viewport_container.get_local_mouse_position()
	var scale = sub_viewport_container.size / FULL_SIZE
	return local_mouse / scale

func round_offsets() -> void:
	sprite_offset = sprite_offset.round()
	
func add_cell_ui(index: int) -> void:
	var cell = animation_cells[index]
	var cell_ui = ANIM_CELL.instantiate()
	cell_container_g.add_child(cell_ui)
	cell_ui.setup(index)
	cell_ui.cell_clicked.connect(func(): on_cell_clicked(index))
	cell_ui.cell_closed.connect(func(): on_cell_closed(index))
	cell.cell_ui = cell_ui
	
func on_cell_clicked(index: int) -> void:
	if is_playing or origin_set:
		return
	set_active_cell(index)

func on_cell_closed(index: int) -> void:
	if is_playing or origin_set:
		return
		
	if animation_cells.size() <= 1:
		return
	
	delete_cell(index)

func delete_cell(index: int) -> void:
	"""Delete a specific cell"""
	if index < 0 or index >= animation_cells.size():
		return
	
	var cell = animation_cells[index]
	
	if cell.ghost_node and is_instance_valid(cell.ghost_node):
		cell.ghost_node.queue_free()
	
	if cell.cell_ui and is_instance_valid(cell.cell_ui):
		cell.cell_ui.queue_free()
	
	animation_cells.remove_at(index)
	
	rebuild_cell_indices()

	if animation_cells.is_empty():
		active_cell_index = -1
	else:
		var new_index = min(index, animation_cells.size() - 1)
		set_active_cell(new_index)
	
	update_slider_range()
	regenerate_decorate_code()

func set_active_cell(index: int) -> void:
	if index < 0 or index >= animation_cells.size():
		return

	for i in range(animation_cells.size()):
		if animation_cells[i].cell_ui:
			animation_cells[i].cell_ui.cell_selected.button_pressed = false

	active_cell_index = index
	var cell = animation_cells[index]
	if cell.cell_ui:
		cell.cell_ui.cell_selected.button_pressed = true

	if cell.sprite_texture:
		weapon_sprite.texture = cell.sprite_texture
		weapon_sprite.size = cell.sprite_size
		imported_sprite_name = cell.sprite_name
	
	sprite_offset = cell.sprite_offset
	update_weapon_position()

	if not is_playing:
		offset_it_slider.value = index

func create_cell_from_drag() -> void:
	if weapon_sprite.texture == null:
		return
	
	var steps = int(offset_calls_per.value)
	if steps <= 0:
		return
	var ref_offset = DEFAULT_SPRITE_OFFSET
	if active_cell_index >= 0:
		ref_offset = animation_cells[active_cell_index].reference_offset
		delete_cells_after(active_cell_index)
	
	# Calculate start and end positions for interpolation
	var start_pos = ANCHOR_POINT - drag_start_offset
	var end_pos = weapon_sprite.position
	
	for i in range(0, steps):  # Changed from range(1, steps + 1) to range(0, steps)
		var t = float(i + 1) / float(steps)  # i+1 so first frame is at 1/steps, not 0/steps
		var interpolated_pos: Vector2
		
		if curve_points.size() >= 2:
			interpolated_pos = interpolate_along_curve(t)
		else:
			interpolated_pos = start_pos.lerp(end_pos, t)
		
		var interpolated_offset = ANCHOR_POINT - interpolated_pos
		
		if i == 0:
			# Update cell 0 with the first interpolated position
			animation_cells[active_cell_index].sprite_offset = interpolated_offset.round()
			update_cell_ghost(active_cell_index)
		else:
			# Create new cells for subsequent frames
			var new_cell = CellData.new()
			new_cell.sprite_texture = weapon_sprite.texture
			new_cell.sprite_size = weapon_sprite.size
			new_cell.sprite_name = imported_sprite_name
			new_cell.sprite_offset = interpolated_offset.round()
			new_cell.reference_offset = ref_offset
			
			animation_cells.append(new_cell)
			add_cell_ui(animation_cells.size() - 1)
			create_ghost_for_cell(animation_cells.size() - 1)

	update_slider_range()
	set_active_cell(animation_cells.size() - 1)
	regenerate_decorate_code()

func delete_cells_after(index: int) -> void:
	var cells_to_delete = animation_cells.size() - index - 1
	
	for i in range(cells_to_delete):
		var cell_index = animation_cells.size() - 1
		var cell = animation_cells[cell_index]
		
		if cell.ghost_node and is_instance_valid(cell.ghost_node):
			cell.ghost_node.queue_free()
		
		if cell.cell_ui and is_instance_valid(cell.cell_ui):
			cell.cell_ui.queue_free()
		
		animation_cells.remove_at(cell_index)

func create_ghost_for_cell(index: int) -> void:
	var cell = animation_cells[index]
	
	if cell.sprite_texture == null:
		return
	
	var ghost = TEXTURE_GHOST.instantiate()
	sprite_editor_space.add_child(ghost)
	ghost.texture = cell.sprite_texture
	ghost.size = cell.sprite_size
	ghost.stretch_mode = TextureRect.STRETCH_KEEP
	ghost.position = ANCHOR_POINT - cell.sprite_offset
	cell.ghost_node = ghost

func update_cell_ghost(index: int) -> void:
	var cell = animation_cells[index]
	
	if cell.ghost_node and is_instance_valid(cell.ghost_node):
		cell.ghost_node.position = ANCHOR_POINT - cell.sprite_offset

func set_origin_effect() -> void:
	if weapon_sprite.texture == null:
		return
	
	var flash_ghost = TEXTURE_EHANCE.instantiate()
	sprite_editor_space.add_child(flash_ghost)
	flash_ghost.texture = weapon_sprite.texture
	flash_ghost.size = weapon_sprite.size
	flash_ghost.position = weapon_sprite.position
	flash_ghost.play_flash_effect()

func create_curve_line() -> void:
	if curve_line:
		curve_line.queue_free()
	
	curve_line = CURVE_POINT_LINE.instantiate()
	sprite_editor_space.add_child(curve_line)
	curve_line.antialiased = true
	curve_line.z_index = 100

func update_curve_line() -> void:
	if not curve_line:
		return
	
	curve_line.clear_points()
	for point in curve_points:
		curve_line.add_point(point)

func update_curve_line_preview(current_pos: Vector2) -> void:
	if not curve_line:
		return
		
	curve_line.clear_points()
	for point in curve_points:
		curve_line.add_point(point)
	curve_line.add_point(current_pos)

func create_curve_point_visual(pos: Vector2) -> void:
	var point_visual = CURVE_POINT_LINE.instantiate()
	sprite_editor_space.add_child(point_visual)
	point_visual.position = pos
	curve_point_visuals.append(point_visual)

func clear_curve_visual() -> void:
	if curve_line and is_instance_valid(curve_line):
		curve_line.queue_free()
		curve_line = null
	
	for visual in curve_point_visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	curve_point_visuals.clear()
	
	curve_points.clear()

# chatgpt carried for this ngl.
func interpolate_along_curve(t: float) -> Vector2:
	if curve_points.size() < 2:
		return curve_points[0] if curve_points.size() > 0 else Vector2.ZERO
	
	if curve_points.size() == 2:
		return curve_points[0].lerp(curve_points[1], t)
	
	var total_length = 0.0
	var segment_lengths: Array[float] = []

	for i in range(curve_points.size() - 1):
		var length = curve_points[i].distance_to(curve_points[i + 1])
		segment_lengths.append(length)
		total_length += length

	var target_distance = t * total_length
	var accumulated_distance = 0.0
	
	for i in range(segment_lengths.size()):
		if accumulated_distance + segment_lengths[i] >= target_distance:
			var segment_t = (target_distance - accumulated_distance) / segment_lengths[i]
		
			var p0 = curve_points[max(0, i - 1)]
			var p1 = curve_points[i]
			var p2 = curve_points[i + 1]
			var p3 = curve_points[min(curve_points.size() - 1, i + 2)]

			return catmull_rom_interpolate(p0, p1, p2, p3, segment_t)
		
		accumulated_distance += segment_lengths[i]

	return curve_points[curve_points.size() - 1]

# this too lmao
func catmull_rom_interpolate(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 = t * t
	var t3 = t2 * t
	
	var result = Vector2.ZERO
	result += p0 * (-0.5 * t3 + t2 - 0.5 * t)
	result += p1 * (1.5 * t3 - 2.5 * t2 + 1.0)
	result += p2 * (-1.5 * t3 + 2.0 * t2 + 0.5 * t)
	result += p3 * (0.5 * t3 - 0.5 * t2)
	
	return result

func regenerate_decorate_code() -> void:
	var code_lines: Array[String] = []
	var last_sprite_name = ""
	
	for i in range(animation_cells.size()):
		var cell = animation_cells[i]
		
		if cell.sprite_name != last_sprite_name and cell.sprite_name != "":
			code_lines.append("// --- Sprite: %s ---" % cell.sprite_name)

			last_sprite_name = cell.sprite_name

		var movement = cell.sprite_offset - cell.reference_offset
		
		var zdoom_x = DEFAULT_OFFSET.x - movement.x
		var zdoom_y = DEFAULT_OFFSET.y - movement.y
		
		var sprite_code = generate_sprite_code(cell.sprite_name)
		code_lines.append("%s Offset(%d, %d)" % [
			sprite_code, 
			int(round(zdoom_x)), 
			int(round(zdoom_y))
		])
	
	offset_call_list.text = "\n".join(code_lines)
	
func generate_sprite_code(sprite_name: String) -> String:
	if sprite_name == "":
		return "BASB B 1"
		
	var sprite_code = ""
	if sprite_name.length() >= 5:
		sprite_code = sprite_name.substr(0, 4) + " " + sprite_name.substr(4, 1) + " 1"
	elif sprite_name.length() == 4:
		sprite_code = sprite_name + " A 1"
	else:
		sprite_code = sprite_name.pad_zeros(4) + " A 1"
	
	return sprite_code

func start_button_pulse() -> void:
	if button_pulse_tween:
		button_pulse_tween.kill()
	
	button_pulse_tween = create_tween()
	button_pulse_tween.set_loops()
	
	var yellow = Color(1.0, 1.0, 0.0, 1.0)
	var normal = Color(1.0, 1.0, 1.0, 1.0)
	
	button_pulse_tween.tween_property(set_origin_button, "modulate", yellow, 0.5)
	button_pulse_tween.tween_property(set_origin_button, "modulate", normal, 0.5)

func stop_button_pulse() -> void:
	if button_pulse_tween:
		button_pulse_tween.kill()
	set_origin_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

func import_weapon_sprite(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("File does not exist: %s" % path)
		return
	
	var img = Image.new()
	var err = img.load(path)
	if err != OK:
		push_error("Failed to load image: %s (Error code: %d)" % [path, err])
		return
	if img.is_empty():
		push_error("Loaded image is empty: %s" % path)
		return
		
	var new_sprite_name = path.get_file().get_basename()
	
	var asset_path = find_asset_for_sprite(new_sprite_name)
	
	var tex = ImageTexture.create_from_image(img)
	var new_size = tex.get_size()

	var grab_offset = read_grab_offset(path)

	sprite_offset = grab_offset
	
	if active_cell_index >= 0 and active_cell_index < animation_cells.size():
		var cell = animation_cells[active_cell_index]
		cell.sprite_path = asset_path if asset_path != "" else path
		cell.sprite_name = new_sprite_name
		cell.sprite_texture = tex
		cell.sprite_size = new_size
		cell.sprite_offset = sprite_offset
		cell.reference_offset = sprite_offset  # NEW: Set reference to grAb offset

		if cell.ghost_node and is_instance_valid(cell.ghost_node):
			cell.ghost_node.texture = tex
			cell.ghost_node.size = new_size
			update_cell_ghost(active_cell_index)

	imported_sprite_name = new_sprite_name
	weapon_sprite.texture = tex
	weapon_sprite.size = new_size
	weapon_sprite.stretch_mode = TextureRect.STRETCH_KEEP
	weapon_sprite.pivot_offset = Vector2.ZERO
	
	update_weapon_position()
	imported_sprite_path = path

	last_imported_sprite_name = new_sprite_name
	
	if animation_cells.is_empty():
		var new_cell = CellData.new()
		new_cell.sprite_texture = tex
		new_cell.sprite_size = new_size
		new_cell.sprite_name = new_sprite_name
		new_cell.sprite_offset = sprite_offset
		new_cell.reference_offset = sprite_offset  # NEW: Set reference to grAb offset
		animation_cells.append(new_cell)
		add_cell_ui(0)
		create_ghost_for_cell(0)
		set_active_cell(0)
	else:
		var cell = animation_cells[active_cell_index]
		cell.sprite_texture = tex
		cell.sprite_name = new_sprite_name
		cell.sprite_offset = sprite_offset
		cell.reference_offset = sprite_offset  # NEW: Set reference to grAb offset
		update_cell_ghost(active_cell_index)

	update_slider_range()
	regenerate_decorate_code()

# and this what the hell
func read_grab_offset(path: String) -> Vector2:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return DEFAULT_SPRITE_OFFSET
	
	var signature = file.get_buffer(8)
	var expected = PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	if signature != expected:
		file.close()
		return DEFAULT_SPRITE_OFFSET
	
	# Read chunks
	while not file.eof_reached():
		if file.get_position() + 8 > file.get_length():
			break
		
		# Read chunk length (big-endian)
		var length_bytes = file.get_buffer(4)
		var length = (length_bytes[0] << 24) | (length_bytes[1] << 16) | (length_bytes[2] << 8) | length_bytes[3]
		
		# Read chunk type
		var chunk_type = file.get_buffer(4).get_string_from_ascii()
		
		if chunk_type == "grAb":
			if length >= 8:
				var data = file.get_buffer(8)
				
				# PNG uses big-endian, so decode manually
				var x = (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3]
				var y = (data[4] << 24) | (data[5] << 16) | (data[6] << 8) | data[7]
				
				# Convert from unsigned to signed if needed
				if x > 0x7FFFFFFF:
					x = x - 0x100000000
				if y > 0x7FFFFFFF:
					y = y - 0x100000000
				
				file.close()
				print("Found grAb offset: (%d, %d)" % [x, y])
				return Vector2(x, y)
			else:
				# Skip remaining data and CRC
				file.seek(file.get_position() + length + 4)
		else:
			# Skip chunk data and CRC (4 bytes)
			file.seek(file.get_position() + length + 4)
	
	file.close()
	return DEFAULT_SPRITE_OFFSET

func find_asset_for_sprite(sprite_name: String) -> String:
	var search_paths = [
		"res://_assets/",
		"user://_assets/", 
	]
	
	for base_path in search_paths:
		var full_path = base_path + sprite_name + ".png"
		if FileAccess.file_exists(full_path):
			return full_path

		for ext in [".jpeg", ".jpg", ".bmp", ".tga", ".webp"]:
			full_path = base_path + sprite_name + ext
			if FileAccess.file_exists(full_path):
				return full_path
	
	return ""

func _on_import_button_pressed() -> void:
	file_dialog.popup()

func _on_file_dialog_file_selected(path: String) -> void:
	import_weapon_sprite(path)
	kill_invalid_cells()

func _on_set_origin_button_pressed() -> void:
	if is_playing:
		return
	
	origin_set = !origin_set
	
	if origin_set:
		if active_cell_index >= 0 and active_cell_index < animation_cells.size():
			animation_cells[active_cell_index].sprite_offset = sprite_offset.round()
			update_cell_ghost(active_cell_index)
			delete_cells_after(active_cell_index)
			regenerate_decorate_code()
		
		set_origin_effect()
		start_button_pulse()
		play_button.disabled = true
	else:
		stop_button_pulse()
		play_button.disabled = false
		clear_curve_visual()
	
func _on_reset_offset_button_pressed() -> void:
	for cell in animation_cells:
		if cell.ghost_node and is_instance_valid(cell.ghost_node):
			cell.ghost_node.queue_free()
		if cell.cell_ui and is_instance_valid(cell.cell_ui):
			cell.cell_ui.queue_free()

	animation_cells.clear()
	active_cell_index = -1
	
	if is_playing:
		stop_playback()
	clear_curve_visual()
	
	create_default_cell() 
	
	set_active_cell(0)

	kill_invalid_cells()
	regenerate_decorate_code()
	
func _on_make_cell_button_pressed() -> void:
	if is_playing:
		return
	var new_cell = CellData.new()
	new_cell.sprite_texture = weapon_sprite.texture
	new_cell.sprite_size = weapon_sprite.size
	new_cell.sprite_name = imported_sprite_name
	new_cell.sprite_offset = sprite_offset
	
	if active_cell_index >= 0 and active_cell_index < animation_cells.size():
		new_cell.reference_offset = animation_cells[active_cell_index].reference_offset
	else:
		new_cell.reference_offset = sprite_offset
	
	var insert_index = active_cell_index + 1 if active_cell_index >= 0 and active_cell_index < animation_cells.size() else animation_cells.size()

	if insert_index < animation_cells.size():
		delete_cells_after(insert_index - 1)

	animation_cells.append(new_cell)
	var new_index = animation_cells.size() - 1
	
	add_cell_ui(new_index)
	create_ghost_for_cell(new_index)

	set_active_cell(new_index)

	update_slider_range()
	regenerate_decorate_code()

func kill_invalid_cells() -> void:
	var i = animation_cells.size() - 1
	while i >= 0:
		var cell = animation_cells[i]
		if cell.sprite_texture == null or cell.sprite_name == "":
			if cell.ghost_node: cell.ghost_node.queue_free()
			if cell.cell_ui: cell.cell_ui.queue_free()
			animation_cells.remove_at(i)
		i -= 1

	rebuild_cell_indices()
	regenerate_decorate_code()

func rebuild_cell_indices() -> void:
	for i in range(animation_cells.size()):
		var cell = animation_cells[i]
		if cell.cell_ui and is_instance_valid(cell.cell_ui):
			cell.cell_ui.setup(i)
			if cell.cell_ui.cell_clicked.is_connected(on_cell_clicked):
				for connection in cell.cell_ui.cell_clicked.get_connections():
					cell.cell_ui.cell_clicked.disconnect(connection.callable)
			
			if cell.cell_ui.cell_closed.is_connected(on_cell_closed):
				for connection in cell.cell_ui.cell_closed.get_connections():
					cell.cell_ui.cell_closed.disconnect(connection.callable)
					
			cell.cell_ui.cell_clicked.connect(func(): on_cell_clicked(i))
			cell.cell_ui.cell_closed.connect(func(): on_cell_closed(i))
	

func _on_play_button_pressed() -> void:
	if animation_cells.is_empty():
		return
	
	if is_playing:
		stop_playback()
	else:
		start_playback()

func start_playback() -> void:
	is_playing = true
	current_frame_index = 0
	
	set_origin_button.disabled = true
	import_button.disabled = true
	sprite_offset_x_box.editable = false
	sprite_offset_y_box.editable = false
	offset_it_slider.editable = false

	play_button.text = "Stop"

	playback_timer.start()
	_on_playback_tick()

func stop_playback() -> void:
	is_playing = false
	playback_timer.stop()

	set_origin_button.disabled = false
	import_button.disabled = false
	sprite_offset_x_box.editable = true
	sprite_offset_y_box.editable = true
	offset_it_slider.editable = true

	play_button.text = "Play"

	if active_cell_index >= 0 and active_cell_index < animation_cells.size():
		set_active_cell(active_cell_index)

func _on_playback_tick() -> void:
	if current_frame_index >= animation_cells.size():
		current_frame_index = 0
	
	if current_frame_index < animation_cells.size():
		var cell = animation_cells[current_frame_index]

		if cell.sprite_texture:
			weapon_sprite.texture = cell.sprite_texture
			weapon_sprite.size = cell.sprite_size
		
		sprite_offset = cell.sprite_offset
		update_weapon_position()
		
		offset_it_slider.value = current_frame_index
		
		current_frame_index += 1

func _on_default_offsets_button_pressed() -> void:
	if animation_cells.is_empty():
		return
		
	if active_cell_index < 0:
		return
		
	var cell = animation_cells[active_cell_index]
	if imported_sprite_path.is_empty():
		return
		
	var grab_offset = read_grab_offset(imported_sprite_path)
	sprite_offset = grab_offset
	cell.sprite_offset = sprite_offset
	update_weapon_position()
	update_cell_ghost(active_cell_index)
	regenerate_decorate_code()

func _on_offset_it_slider_value_changed(value: float) -> void:
	if is_playing:
		return
	
	var index = int(value)
	if index >= 0 and index < animation_cells.size():
		set_active_cell(index)

func update_slider_range() -> void:
	if animation_cells.is_empty():
		offset_it_slider.min_value = 0
		offset_it_slider.max_value = 0
		offset_it_slider.value = 0
	else:
		offset_it_slider.min_value = 0
		offset_it_slider.max_value = animation_cells.size() - 1
		if active_cell_index >= 0 and active_cell_index < animation_cells.size():
			offset_it_slider.value = active_cell_index
