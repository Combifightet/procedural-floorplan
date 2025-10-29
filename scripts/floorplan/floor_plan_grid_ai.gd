extends RefCounted
class_name FloorPlanGridAi

## Implements the room expansion algorithm for floor plan generation

# TODO: replace with custom data class maybe `FloorPlanCell.Grid`
var grid: Array[Array] = [] ## should be of type `Array[Array[FloorPlanCell]]`
var width: int = 0
var height: int = 0
var grid_resolution: int = 1


func _init(w: int, h: int, resolution: int = 1) -> void:
	print("    width:  ", w)
	print("    height: ", h)
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
static func from_points(points: 
Array[Vector2], resolution: int = 1) -> FloorPlanGridAi:
	assert(resolution>=1, "resoltion must be a natual number (e.g >= 1)")
	if points.is_empty():
		return null
	const padding: int = 1
	
	var bounds: Rect2 = _get_bounds(points)
	assert(bounds.is_finite(), "bounding box can't be infinite")
	var grid_size: Vector2 = snap2(bounds.end, 1.0/resolution)-snap2(bounds.position, 1.0/resolution) # get min grid dimension
	grid_size *= resolution # scale with resolution
	grid_size += Vector2.ONE*2*padding # add padding around the building grid

	
	var floor_grid: FloorPlanGridAi = FloorPlanGridAi.new(floor(grid_size).x, floor(grid_size).y, resolution)
	
	# Mark cells inside the polygon as empty, outside as OUTSIDE
	var origin: Vector2 = snap2(bounds.position, 1.0/resolution) - Vector2.ONE*padding/resolution
	var world_pos: Vector2
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			world_pos = origin + Vector2(x, y)/resolution
			# TODO: propably most of this code is wrong lol ._.
			# print("is_outside(",x, ", ", y, ") -> ", _is_point_in_polygon(world_pos, points))
			# print("  world_pos: ", world_pos)
			if not _is_point_in_polygon(world_pos, points):
				floor_grid.get_cell(x,y).set_outside()
	
	return floor_grid


static func snap(value: float, increment: float = 1) -> float:
	return floor(value/increment)*increment
	
static func snap2(value: Vector2, increment: float = 1) -> Vector2:
	return Vector2(
		snap(value.x, increment),
		snap(value.y, increment)
	)


## Get cell at position, returns null if out of bounds
func get_cell(x: int, y: int) -> FloorPlanCell:
	if x < 0 or x >= width or y < 0 or y >= height:
		return null
	return grid[y][x]


## Check if a point is inside a polygon using ray casting algorithm
static func _is_point_in_polygon(point: Vector2, polygon: Array[Vector2]) -> bool:
	if polygon.size()<=2:
		return false
	
	var inside = false
	const d: Vector2 = Vector2(cos(PI/42), sin(PI/42))
	var v1: Vector2
	var v2: Vector2
	const v3: Vector2 = Vector2(-d.y, d.x)
	var t1: float
	var t2: float
	
	var current_point: Vector2 = polygon[-1]
	for next_point in polygon:
		v1 = point-current_point
		v2 = next_point-current_point
		t1 = v2.cross(v1)/v2.dot(v3)
		if t1>0: # ray points in direction of line (segment)
			t2 = v1.dot(v3)/v2.dot(v3)
			if t2>=0 and t2<1: # ray hits inbetween current_point (inclusive) and next_point (exlusive)
				inside = not inside
		
		current_point = next_point
	
	return inside


## returns the axis aligned bounding box of a given point list
static func _get_bounds(points: Array[Vector2]) -> Rect2:
	if points.is_empty():
		return Rect2()
	
	var min_bounds: Vector2 = Vector2.INF
	var max_bounds: Vector2 = -Vector2.INF
	
	for point in points:
		if point.x < min_bounds.x:
			min_bounds.x = point.x
		if point.x > max_bounds.x:
			max_bounds.x = point.x
		if point.y < min_bounds.y:
			min_bounds.y = point.y
		if point.y > max_bounds.y:
			max_bounds.y = point.y
	
	return Rect2(min_bounds, max_bounds-min_bounds)


## Places initial room seeds based on weights
func place_rooms(rooms: Array[RoomArea]):
	if rooms.is_empty():
		return
	
	var room_start_positions: Dictionary[int, Vector2i] = {}
	var wall_dist_field: Array[Array] = _calculate_wall_distance_field()
	var total_inside_cells: int = _get_total_inside_cells()
	
	for room in rooms:
		# 1. Create base scoring grid based on wall distance
		var scoring_grid: Array[Array] = _create_base_scoring_grid(room, total_inside_cells, wall_dist_field)
		
		# 2. Apply adjacency bonuses
		_apply_adjacency_bonuses(scoring_grid, room, room_start_positions)
		
		# 3. Apply penalties to avoid clustering with already-placed rooms
		_apply_clustering_penalties(scoring_grid, room_start_positions)
		
		# 4. Select a weighted random cell
		var chosen_pos: Vector2i = _select_weighted_random_cell(scoring_grid)
		
		if chosen_pos.x == -1:
			# Fallback: No weighted cell found, try to find *any* empty cell
			push_warning("No suitable weighted position found for room %d. Trying fallback." % room.id)
			chosen_pos = _find_any_empty_cell()
		
		if chosen_pos.x == -1:
			# Total failure
			push_error("Could not place initial seed for room %d. Floor plan generation might fail." % room.id)
			continue
		
		# 5. Place the room and store its position
		var cell: FloorPlanCell = get_cell(chosen_pos.x, chosen_pos.y)
		if cell:
			cell.grow(room.id)
			room_start_positions[room.id] = chosen_pos
		else:
			push_error("Chosen position %s for room %d is invalid." % [chosen_pos, room.id])


## --- Helper Functions for Room Placement ---

## Calculates a distance field from the nearest "OUTSIDE" cell for all "inside" cells.
func _calculate_wall_distance_field() -> Array[Array]:
	var dist_field: Array[Array] = []
	var queue: Array[Vector2i] = []
	
	# Initialize grid
	for y in range(height):
		var row: Array[int] = []
		row.resize(width)
		dist_field.append(row)
		for x in range(width):
			var cell: FloorPlanCell = get_cell(x, y)
			if cell.is_outside():
				dist_field[y][x] = 0
			else:
				dist_field[y][x] = -1 # Mark as unvisited

	# Pass 1: Find all inside cells adjacent to an outside wall
	var neighbors: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for y in range(height):
		for x in range(width):
			if dist_field[y][x] == -1: # If it's an inside cell
				var is_near_wall: bool = false
				for offset in neighbors:
					var nx: int = x + offset.x
					var ny: int = y + offset.y
					var neighbor_cell: FloorPlanCell = get_cell(nx, ny)
					if neighbor_cell == null or neighbor_cell.is_outside():
						is_near_wall = true
						break
				if is_near_wall:
					dist_field[y][x] = 1
					queue.append(Vector2i(x, y))

	# Pass 2: BFS (Brushfire) to propagate distances
	var head: int = 0
	while head < queue.size():
		var pos: Vector2i = queue[head]
		head += 1
		var current_dist: int = dist_field[pos.y][pos.x]
		
		for offset in neighbors:
			var n_pos: Vector2i = pos + offset
			if n_pos.x >= 0 and n_pos.y >= 0 and n_pos.x < width and n_pos.y < height:
				if dist_field[n_pos.y][n_pos.x] == -1: # Unvisited inside cell
					dist_field[n_pos.y][n_pos.x] = current_dist + 1
					queue.append(n_pos)
					
	return dist_field


## Counts all cells that are not marked as OUTSIDE
func _get_total_inside_cells() -> int:
	var count: int = 0
	for y in range(height):
		for x in range(width):
			if not get_cell(x, y).is_outside():
				count += 1
	return count


## Creates the initial scoring grid based on room size and wall distance
func _create_base_scoring_grid(room: RoomArea, total_inside_cells: int, wall_dist_field: Array[Array]) -> Array[Array]:
	var scoring_grid: Array[Array] = []
	var desired_area_cells: float = room.rel_size * total_inside_cells
	# Estimate a "radius" or minimum distance based on area.
	var min_dist_from_wall: int = floor(sqrt(desired_area_cells) / 2.0)
	
	for y in range(height):
		var row: Array[float] = []
		row.resize(width)
		scoring_grid.append(row)
		for x in range(width):
			if get_cell(x, y).is_outside():
				scoring_grid[y][x] = 0.0
			else:
				var dist: int = wall_dist_field[y][x]
				# Give weight of 1 if distance is sufficient, 0 otherwise
				if dist >= min_dist_from_wall:
					scoring_grid[y][x] = 1.0
				else:
					scoring_grid[y][x] = 0.0 # Cells too close to wall are penalized
	return scoring_grid


## Modifies the scoring grid to add high values near desired adjacent rooms
func _apply_adjacency_bonuses(scoring_grid: Array[Array], room: RoomArea, room_start_positions: Dictionary) -> void:
	const ADJACENCY_BONUS: float = 10.0 # "high values"
	const ADJACENCY_RADIUS: int = 3 # How far the bonus extends

	for adj_room_id in room.connectivity:
		if room_start_positions.has(adj_room_id):
			var pos: Vector2i = room_start_positions[adj_room_id]
			
			for dy in range(-ADJACENCY_RADIUS, ADJACENCY_RADIUS + 1):
				for dx in range(-ADJACENCY_RADIUS, ADJACENCY_RADIUS + 1):
					var check_x: int = pos.x + dx
					var check_y: int = pos.y + dy
					
					if check_x >= 0 and check_y >= 0 and check_x < width and check_y < height:
						# Only apply bonus to valid, non-outside cells
						if not get_cell(check_x, check_y).is_outside():
							scoring_grid[check_y][check_x] += ADJACENCY_BONUS


## Modifies the scoring grid to set weights to zero around already-placed rooms
func _apply_clustering_penalties(scoring_grid: Array[Array], room_start_positions: Dictionary) -> void:
	const CLUSTER_RADIUS: int = 2 # How close is "too close"

	for placed_pos in room_start_positions.values():
		for dy in range(-CLUSTER_RADIUS, CLUSTER_RADIUS + 1):
			for dx in range(-CLUSTER_RADIUS, CLUSTER_RADIUS + 1):
				var check_x: int = placed_pos.x + dx
				var check_y: int = placed_pos.y + dy
				
				if check_x >= 0 and check_y >= 0 and check_x < width and check_y < height:
					scoring_grid[check_y][check_x] = 0.0


## Selects a cell randomly, weighted by its score. Returns (-1, -1) on failure.
func _select_weighted_random_cell(scoring_grid: Array[Array]) -> Vector2i:
	var valid_cells: Array[Vector2i] = []
	var weights: Array[float] = []
	var total_weight: float = 0.0
	
	for y in range(height):
		for x in range(width):
			var weight: float = scoring_grid[y][x]
			# Cell must have score > 0 and be empty
			if weight > 0.0 and get_cell(x, y).is_empty():
				valid_cells.append(Vector2i(x, y))
				weights.append(weight)
				total_weight += weight
	
	if total_weight == 0.0:
		return Vector2i(-1, -1) # No valid cell found
	
	var r: float = randf() * total_weight
	for i in range(valid_cells.size()):
		r -= weights[i]
		if r <= 0.0:
			return valid_cells[i]
			
	return valid_cells[-1] # Fallback in case of floating point weirdness


## Finds the first available empty cell. Returns (-1, -1) on failure.
func _find_any_empty_cell() -> Vector2i:
	for y in range(height):
		for x in range(width):
			if get_cell(x, y).is_empty():
				return Vector2i(x, y)
	return Vector2i(-1, -1) # No empty cells left


## Debug: Print grid
func print_grid() -> void:
	for y: int in range(height):
		var row_str: String = ""
		for x: int in range(width):
			var cell: FloorPlanCell = get_cell(x,y)
			if cell.is_outside():
				row_str += " X "
			elif cell.is_empty():
				row_str += " . "
			else:
				row_str += "%2d " % cell.room_id
		print(row_str)