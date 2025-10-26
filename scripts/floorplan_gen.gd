extends Node2D

@export_range(4, 20) var vertices: int = 3 # 10
@export_range(0, 1) var randomness_slider: float = 0.8
@export var seed_value: int = 0
@export var grid_scale: int = 25
@export var radius: int = 200 # Made radius a class variable

var vectors: Array[Vector2] = []
var original_points: Array[Vector2] = [] # To store the points on the circle
var original_directions: Array[Vector2] = [] # To store the outgoing directions

var button: Button
var vertex_slider: HSlider
var random_slider: HSlider
var vertex_label: Label
var random_label: Label
var ui_container: Control

enum Direction {N=0, E=1, S=2, W=3}
var DIRECTION_VECTORS: Dictionary[Direction, Vector2] = {
	Direction.N: Vector2.UP,
	Direction.E: Vector2.RIGHT,
	Direction.S: Vector2.DOWN,
	Direction.W: Vector2.LEFT,
}
var VECTOR_DIRECTIONS: Dictionary[Vector2, Direction] = {
	Vector2.UP: Direction.N,
	Vector2.RIGHT: Direction.E,
	Vector2.DOWN: Direction.S,
	Vector2.LEFT: Direction.W
}

enum MapSize {SMALL=0, NORMAL=1, LARGE=2}
var RADIUS_DICT: Dictionary[MapSize, int]
var GRIDSIZE_DICT: Dictionary[MapSize, int]

func _ready() -> void:
	# Create UI container
	ui_container = Control.new()
	ui_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	add_child(ui_container)
	
	# Position UI elements relative to top-right
	# Create button
	button = Button.new()
	button.text = "Regenerate Polygon"
	button.size = Vector2(180, 40)
	button.pressed.connect(_on_regenerate_button_pressed)
	ui_container.add_child(button)
	
	# Create label for slider
	vertex_label = Label.new()
	vertex_label.text = "Vertices: " + str(vertices)
	vertex_label.size = Vector2(180, 30)
	ui_container.add_child(vertex_label)
	# Create slider
	vertex_slider = HSlider.new()
	vertex_slider.size = Vector2(180, 30)
	vertex_slider.min_value = 4
	vertex_slider.max_value = 20
	vertex_slider.step = 1
	vertex_slider.value = vertices
	vertex_slider.value_changed.connect(_on_vertex_slider_changed)
	ui_container.add_child(vertex_slider)
	
	
	# Create label for slider
	random_label = Label.new()
	random_label.text = "Randomness: " + str(randomness_slider)
	random_label.size = Vector2(180, 30)
	ui_container.add_child(random_label)
	# Create slider
	random_slider = HSlider.new()
	random_slider.size = Vector2(180, 30)
	random_slider.min_value = 0.0
	random_slider.max_value = 1.0
	random_slider.step = 0.01
	random_slider.value = randomness_slider
	random_slider.value_changed.connect(_on_random_slider_changed)
	ui_container.add_child(random_slider)
	
	# Generate initial polygon
	generate_new_polygon()

func _process(_delta: float) -> void:
	# Update UI position to follow camera
	var camera = get_viewport().get_camera_2d()
	if camera:
		var viewport_size = get_viewport_rect().size
		var camera_pos = camera.get_screen_center_position()
		var camera_zoom = camera.zoom
		
		# Calculate top-right position in world space
		var top_right = camera_pos + Vector2(viewport_size.x / (2 * camera_zoom.x), -viewport_size.y / (2 * camera_zoom.y))
		
		# Position UI container
		ui_container.global_position = top_right - Vector2(200, -10) / camera_zoom
		ui_container.scale = Vector2.ONE / camera_zoom
		
		# Position UI elements
		button.position = Vector2(0, 0)
		vertex_label.position = Vector2(0, 50)
		vertex_slider.position = Vector2(0, 80)
		random_label.position = Vector2(0, 130)
		random_slider.position = Vector2(0, 160)

func randf_r(randomness: float) -> float:
	randomness = clamp(randomness, 0, 1)
	return randf()*randomness+(1-randomness)

func _on_regenerate_button_pressed() -> void:
	randomize()
	generate_new_polygon()

func _on_vertex_slider_changed(value: float) -> void:
	vertices = int(value)
	vertex_label.text = "Vertices: " + str(vertices)
	generate_new_polygon()

func _on_random_slider_changed(value: float) -> void:
	randomness_slider = value
	random_label.text = "Randomness: " + str(randomness_slider)
	generate_new_polygon()

func generate_new_polygon() -> void:
	# Use current time as seed for randomness_slider
	# randomize()
	
	vectors = generate_building_outline()
	vectors = simplyfy_polygon(vectors)
	# center_polygon() # Removed auto-centering as requested
	queue_redraw()

func _draw() -> void:
	# --- Draw the background grid ---
	var camera = get_viewport().get_camera_2d()
	if camera and grid_scale > 0:
		var viewport_size = get_viewport_rect().size
		var camera_pos = camera.get_screen_center_position()
		var camera_zoom = camera.zoom
		
		# Calculate visible area in world coordinates
		var top_left = camera_pos - (viewport_size / (2 * camera_zoom))
		var bottom_right = camera_pos + (viewport_size / (2 * camera_zoom))
		
		# Add a small buffer to avoid dots popping in/out at the edges
		var buffer = grid_scale * 2 # Added a bit more buffer
		
		# Find the nearest grid-aligned start and end points
		var start_x = floor((top_left.x - buffer) / grid_scale) * grid_scale
		var start_y = floor((top_left.y - buffer) / grid_scale) * grid_scale
		var end_x = ceil((bottom_right.x + buffer) / grid_scale) * grid_scale
		var end_y = ceil((bottom_right.y + buffer) / grid_scale) * grid_scale
		
		var dot_color = Color(0.5, 0.5, 0.5, 0.3) # Faint gray
		var dot_radius = 2.0
		
		var x = start_x
		while x <= end_x:
			var y = start_y
			while y <= end_y:
				draw_circle(Vector2(x, y), dot_radius, dot_color)
				y += grid_scale
			x += grid_scale
	
	# --- Draw the final generated polygon ---
	if vectors.size() > 2:
		# Draw filled polygon
		draw_colored_polygon(vectors, Color(0.3, 0.5, 0.8, 0.7))
		
		# Draw outline
		for i in range(vectors.size()):
			var next_i = (i + 1) % vectors.size()
			draw_line(vectors[i], vectors[next_i], Color.WHITE, 2.0)
		
		# Draw vertices as dots
		for point in vectors:
			draw_circle(point, 4.0, Color(1.0, 0.3, 0.3)) # Red dots
			
	# --- Draw the generation circle ---
	# Draw a thin grey circle outline
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(0.5, 0.5, 0.5, 0.5), 2.0, true)

	# --- Draw the original points and their indices ---
	if original_points.size() > 0:
		var font = SystemFont.new()
		var font_size = 16
		
		var arrow_color = Color.CYAN
		var arrow_length = 30.0
		var arrowhead_length = 8.0
		var arrowhead_angle = PI / 6 # 30 degrees
		
		for i in range(original_points.size()):
			var p = original_points[i]
			
			# 1. Draw the original point highlighted (e.g., as a larger yellow circle)
			# draw_circle(p, 6.0, Color.YELLOW)
			
			# 2. Draw the index number next to the point
			var text = str(i)
			# Get text size to offset it properly (optional, but good)
			var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			# Draw string slightly offset from the point
			draw_string(font, p + Vector2(10, -text_size.y / 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
			
			# 3. Draw the outgoing direction arrow
			if i < original_directions.size():
				var dir_vec = original_directions[i]
				if dir_vec.is_normalized(): # Ensure it's a direction vector
					var end_point = p + dir_vec * arrow_length
					
					# Draw main arrow line
					draw_line(p, end_point, arrow_color, 2.0)
					
					# Draw arrowhead
					# Tip 1 (rotate vector 180 deg + angle)
					var arrow_tip_1 = end_point + dir_vec.rotated(PI + arrowhead_angle) * arrowhead_length
					draw_line(end_point, arrow_tip_1, arrow_color, 2.0)
					# Tip 2 (rotate vector 180 deg - angle)
					var arrow_tip_2 = end_point + dir_vec.rotated(PI - arrowhead_angle) * arrowhead_length
					draw_line(end_point, arrow_tip_2, arrow_color, 2.0)


func _get_invalid_dir(vec: Vector2) -> Direction:
	var invalid_dir: Direction
	if abs(vec.x) >= abs(vec.y):
		if vec.x >= 0:
			invalid_dir = Direction.N
		else:
			invalid_dir = Direction.S
	else:
		if vec.y >= 0:
			invalid_dir = Direction.E
		else:
			invalid_dir = Direction.W
	return invalid_dir

func _get_rand_valid_travel_direction(vec: Vector2, incoming_dir: int = -1) -> Direction:
	var invalid_dir: Direction = _get_invalid_dir(vec)
	var invalid_dir_2: Direction = _get_invalid_dir(vec.rotated(2*PI/16))
	if invalid_dir_2==invalid_dir:
		invalid_dir_2 = _get_invalid_dir(vec.rotated(-2*PI/16))

	print('vec: ', vec)
	print('  -> incoming_dir:', incoming_dir)
	print('  -> invalid_dir: ', invalid_dir)
	print('  -> invalid_dir_2: ', invalid_dir_2)
	
	var output_dir: Direction
	if incoming_dir == -1:
		@warning_ignore("integer_division") 
		output_dir = (invalid_dir+len(Direction)/2)%len(Direction) as Direction
	else:
		output_dir = randi_range(0, len(Direction)-1) as Direction
	print('    -> output_dir: ', output_dir)
	# flip direction if it is invalid
	if output_dir == invalid_dir:
		@warning_ignore("integer_division") 
		output_dir = (output_dir+len(Direction)/2)%len(Direction)  as Direction
		print('    -> output_dir: ', output_dir, ' (flipped)')
	if invalid_dir_2!=invalid_dir and output_dir == invalid_dir_2:
		@warning_ignore("integer_division") 
		output_dir = (output_dir+len(Direction)/2)%len(Direction)  as Direction
		print('    -> output_dir: ', output_dir, ' (flipped_2)')
		
	# if selected output direction is the input direction rotate input clockwise untill not inside the invalid_dir
	@warning_ignore("integer_division") 
	if incoming_dir != -1 and output_dir == (incoming_dir+len(Direction)/2)%len(Direction):
		# assert(len(Direction)>=3, "Need at least 3 directions or this might be a `while true:` loop")
		while true:
			output_dir = (output_dir+1)%len(Direction) as Direction
			print('    -> output_dir: ', output_dir, ' (rotated)')
			@warning_ignore("integer_division") 
			if output_dir!=invalid_dir and output_dir!=invalid_dir_2 and output_dir!=(incoming_dir+len(Direction)/2)%len(Direction):
				break
	
	return output_dir

func _get_connection_points(point_a: Vector2, point_b: Vector2, start_direction: Vector2) -> Array[Vector2]:
	print('  -> _get_connection_points(')
	print('         point_a: ', point_a)
	print('         point_b: ', point_b)
	print('         start_direction: ', start_direction)
	print('     )')
	var simple_connection: bool = start_direction.x*(point_b.x-point_a.x) > 0 or start_direction.y*(point_b.y-point_a.y) > 0
	
	var result: Array[Vector2]
	
	print('    -> simple_connection: ', simple_connection)
	
	if simple_connection:
		result = [
			Vector2(
				point_a + Vector2((point_b.x-point_a.x) * abs(start_direction.x), (point_b.y-point_a.y) * abs(start_direction.y))
			)
		]
	else:
		result = [
			Vector2(
				point_a - Vector2((point_b.x-point_a.x) * abs(start_direction.x), (point_b.y-point_a.y) * abs(start_direction.y))
			)
		]
		result.append(
			2*result[0]+point_b-2*point_a
		)
	
	return result


func generate_building_outline() -> Array[Vector2]:
	# Use the class variable 'original_points' instead of a local 'points'
	original_points.clear()
	original_directions.clear() # Clear directions as well

		
	# Use the class variable 'radius'
	var dists: Array[float] = [0]
	var total_dist: float = 0
	for i in range(1, vertices):
		dists.append(dists[-1]+randf_r(randomness_slider))
	print('-------------------------')
	print('dists: ', dists)
	total_dist = dists[-1]+randf_r(randomness_slider)
	
	for point in dists:
		# Add points to the class variable
		original_points.append((Vector2.from_angle(point/total_dist*2*PI) * radius).snapped(Vector2.ONE*grid_scale))
	print('original_points: ', original_points)
	# now connect the points in a sensible manner	
	var result: Array[Vector2] = []
	var incoming_dir: int = -1
	
	for i in range(original_points.size()):
		var point_a = original_points[i]
		var point_b = original_points[(i + 1) % original_points.size()]
		
		result.append(point_a)
		
		# Base direction on vector to next point
		var vec_to_next = (point_b - point_a)
		if vec_to_next.is_zero_approx():
			print('ERROR POINTS ARE IDENTICAL')
			vec_to_next = Vector2.UP # Default if points are the same
			
		var travel_dir: Direction = _get_rand_valid_travel_direction(point_a, incoming_dir)
		var travel_vec: Vector2 = DIRECTION_VECTORS[travel_dir]
		
		original_directions.append(travel_vec) # Store direction for drawing
				
		result.append_array(_get_connection_points(point_a, point_b, travel_vec))
		
		var incoming_vec: Vector2 = original_points[(i+1)%len(original_points)]-result[-1]
		incoming_vec = incoming_vec.normalized()
		if incoming_vec.is_equal_approx(Vector2.ZERO):
			incoming_dir = -1
		else:
			incoming_dir = VECTOR_DIRECTIONS[incoming_vec]
	
	return result

func center_polygon() -> void:
	if vectors.size() == 0:
		return
	
	# Calculate bounding box
	var min_x = vectors[0].x
	var max_x = vectors[0].x
	var min_y = vectors[0].y
	var max_y = vectors[0].y
	
	for point in vectors:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)
	
	# Calculate center offset
	var center_offset = Vector2(
		-(min_x + max_x) / 2.0,
		-(min_y + max_y) / 2.0
	)
	
	# Apply offset to all points
	for i in range(vectors.size()):
		vectors[i] += center_offset

func simplyfy_polygon(polygon: Array[Vector2]) -> Array[Vector2]:
	var simple_polygon: Array[Vector2] = []
	
	# remove identical points
	var point: Vector2 = polygon[-1]
	for next_point in polygon:
		if not point.is_equal_approx(next_point):
			simple_polygon.append(point)
		point = next_point
	polygon = simple_polygon
	simple_polygon = []
	
	# remove colinear points
	var incoming_vec: Vector2 = polygon[-1]-polygon[-2]
	incoming_vec  = incoming_vec.normalized()
	
	point = polygon[-1]
	for next_point in polygon:
		var outgoing_vec: Vector2 = next_point-point
		outgoing_vec = outgoing_vec.normalized()
		
		print('---------------------------')
		print('incoming_vec: ', incoming_vec)
		print('outgoing_vec: ', outgoing_vec)
		if not incoming_vec.is_equal_approx(outgoing_vec):
			simple_polygon.append(point)
		incoming_vec = outgoing_vec
		point = next_point
	
	return simple_polygon
