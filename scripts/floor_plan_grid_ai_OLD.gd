extends RefCounted


## Implements the room expansion algorithm for floor plan generation

var grid: Array[Array] = []
var width: int = 0
var height: int = 0
var grid_resolution: float = 1.0


func _init(w: int, h: int, resolution: float = 1.0) -> void:
	width = w
	height = h
	grid_resolution = resolution
	_initialize_grid()


## Initialize the grid with empty cells
func _initialize_grid() -> void:
	grid.clear()
	for y in range(height):
		var row: Array[FloorPlanCell] = []
		for x in range(width):
			row.append(FloorPlanCell.new())
		grid.append(row)


## Create grid from a list of boundary points
static func from_points(points: Array[Vector2], resolution: float = 1.0) -> FloorPlanGrid:
	if points.is_empty():
		return null
	
	# Find bounding box
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF
	
	for point in points:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)
	
	# Calculate grid dimensions
	var new_width = int(ceil((max_x - min_x) / resolution)) + 1
	var new_height = int(ceil((max_y - min_y) / resolution)) + 1
	
	var floor_grid = FloorPlanGrid.new(new_width, new_height, resolution)
	
	# Mark cells inside the polygon as empty, outside as OUTSIDE
	for y in range(new_height):
		for x in range(new_width):
			var world_pos = Vector2(min_x + x * resolution, min_y + y * resolution)
			if not _is_point_in_polygon(world_pos, points):
				floor_grid.get_cell(x, y).set_outside()
	
	return floor_grid


## Check if a point is inside a polygon using ray casting algorithm
static func _is_point_in_polygon(point: Vector2, polygon: Array[Vector2]) -> bool:
	var inside = false
	var j = polygon.size() - 1
	
	for i in range(polygon.size()):
		if ((polygon[i].y > point.y) != (polygon[j].y > point.y)) and \
		   (point.x < (polygon[j].x - polygon[i].x) * (point.y - polygon[i].y) / \
		   (polygon[j].y - polygon[i].y) + polygon[i].x):
			inside = not inside
		j = i
	
	return inside


## Get cell at position, returns null if out of bounds
func get_cell(x: int, y: int) -> FloorPlanCell:
	if x < 0 or x >= width or y < 0 or y >= height:
		return null
	return grid[y][x]


## Main algorithm: Room expansion
func generate_floor_plan(room_list: Array[int], room_ratios: Dictionary[int, float]) -> void:
	# First pass: Rectangular growth
	var rooms = _build_room_set(room_list)
	
	while not rooms.is_empty():
		var room = _select_room(rooms, room_ratios)
		var can_grow = _grow_rect(room, room_ratios.get(room, 1.0))
		
		if not can_grow:
			rooms.erase(room)
	
	# Second pass: L-shape growth
	rooms = _build_room_set(room_list)
	
	while not rooms.is_empty():
		var room = _select_room(rooms, room_ratios)
		var can_grow = _grow_l_shape(room)
		
		if not can_grow:
			rooms.erase(room)
	
	# Fill remaining gaps
	if _has_empty_spaces():
		_fill_gaps()


## Build initial room set with seed cells
func _build_room_set(room_list: Array[int]) -> Array[int]:
	var rooms: Array[int] = []
	
	for room_id in room_list:
		# Find an empty cell to seed this room
		var seed_pos = _find_empty_cell()
		if seed_pos != Vector2i(-1, -1):
			get_cell(seed_pos.x, seed_pos.y).grow(room_id)
			rooms.append(room_id)
	
	return rooms


## Select room based on current area vs target ratio
func _select_room(rooms: Array[int], room_ratios: Dictionary) -> int:
	var total_area = _get_total_room_area()
	var best_room = rooms[0]
	var best_diff = INF
	
	for room_id in rooms:
		var current_ratio = float(_get_room_area(room_id)) / total_area if total_area > 0 else 0.0
		var target_ratio = room_ratios.get(room_id, 1.0 / rooms.size())
		var diff = abs(target_ratio - current_ratio)
		
		if diff > best_diff:
			best_diff = diff
			best_room = room_id
	
	return best_room


## Grow room in rectangular pattern
func _grow_rect(room_id: int, _target_ratio: float) -> bool:
	var room_cells = _get_room_cells(room_id)
	if room_cells.is_empty():
		return false
	
	var grown = false
	
	# Try to expand from each cell in the room
	for cell_pos in room_cells:
		var neighbors = _get_empty_neighbors(cell_pos)
		
		for neighbor_pos in neighbors:
			if get_cell(neighbor_pos.x, neighbor_pos.y).grow(room_id):
				grown = true
				break
		
		if grown:
			break
	
	return grown


## Grow room in L-shape pattern
func _grow_l_shape(room_id: int) -> bool:
	var room_cells = _get_room_cells(room_id)
	if room_cells.is_empty():
		return false
	
	var grown = false
	
	# Try L-shaped expansion from corner cells
	for cell_pos in room_cells:
		var neighbors = _get_empty_neighbors(cell_pos)
		
		if neighbors.size() >= 2:
			# Try to form an L-shape
			for i in range(min(2, neighbors.size())):
				if get_cell(neighbors[i].x, neighbors[i].y).grow(room_id):
					grown = true
		
		if grown:
			break
	
	return grown


## Check if there are empty spaces remaining
func _has_empty_spaces() -> bool:
	for y in range(height):
		for x in range(width):
			if get_cell(x, y).is_empty():
				return true
	return false


## Fill remaining gaps with adjacent rooms
func _fill_gaps() -> void:
	for y in range(height):
		for x in range(width):
			var cell = get_cell(x, y)
			if cell.is_empty():
				# Assign to most common neighboring room
				var neighbor_room = _get_most_common_neighbor_room(Vector2i(x, y))
				if neighbor_room != FloorPlanCell.NO_ROOM:
					cell.grow(neighbor_room)


## Helper: Find first empty cell
func _find_empty_cell() -> Vector2i:
	for y in range(height):
		for x in range(width):
			if get_cell(x, y).is_empty():
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Helper: Get all cells belonging to a room
func _get_room_cells(room_id: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			if get_cell(x, y).room_id == room_id:
				cells.append(Vector2i(x, y))
	return cells


## Helper: Get empty neighboring cells
func _get_empty_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	
	for dir in directions:
		var new_pos = pos + dir
		var cell = get_cell(new_pos.x, new_pos.y)
		if cell and cell.is_empty():
			neighbors.append(new_pos)
	
	return neighbors


## Helper: Get most common room ID among neighbors
func _get_most_common_neighbor_room(pos: Vector2i) -> int:
	var room_counts = {}
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	
	for dir in directions:
		var new_pos = pos + dir
		var cell = get_cell(new_pos.x, new_pos.y)
		if cell and not cell.is_empty() and not cell.is_outside():
			var room_id = cell.room_id
			room_counts[room_id] = room_counts.get(room_id, 0) + 1
	
	var best_room = FloorPlanCell.NO_ROOM
	var best_count = 0
	
	for room_id in room_counts:
		if room_counts[room_id] > best_count:
			best_count = room_counts[room_id]
			best_room = room_id
	
	return best_room


## Helper: Get area of a specific room
func _get_room_area(room_id: int) -> int:
	var area = 0
	for y in range(height):
		for x in range(width):
			if get_cell(x, y).room_id == room_id:
				area += 1
	return area


## Helper: Get total area of all rooms
func _get_total_room_area() -> int:
	var area = 0
	for y in range(height):
		for x in range(width):
			var cell = get_cell(x, y)
			if not cell.is_empty() and not cell.is_outside():
				area += 1
	return area


func get_rooms() -> Array[int]:
	var rooms: Array[int] = []
	for y in range(height):
		for x in range(width):
			var cell: FloorPlanCell = get_cell(x, y)
			if not cell.is_empty() and not cell.is_outside() and cell.room_id not in rooms:
				rooms.append(cell.room_id)
	rooms.sort()
	return rooms

## Debug: Print grid
func print_grid() -> void:
	for y in range(height):
		var row_str = ""
		for x in range(width):
			var cell = get_cell(x, y)
			if cell.is_outside():
				row_str += " X "
			elif cell.is_empty():
				row_str += " . "
			else:
				row_str += "%2d " % cell.room_id
		print(row_str)
