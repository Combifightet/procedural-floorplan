extends RefCounted
class_name FloorPlanGrid

## Implements the room expansion algorithm for floor plan generation

# TODO: replace with custom data class maybe `FloorPlanCell.Grid`
var grid: Array[Array] = [] ## should be of type `Array[Array[FloorPlanCell]]`
var width: int = 0
var height: int = 0
var grid_resolution: int = 1

var _room_dict: Dictionary[Vector2i, RoomArea] = {}


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

func _create_int_grid(initial_value:int = 0) -> Array[Array]:
	var int_grid: Array[Array] = [] ## should be of type `Array[Array[int]]`
	for y in range(height):
		var row: Array[int] = []
		for x in range(width):
			row.append(initial_value)
		int_grid.append(row)
	return int_grid


## Create grid from a list of boundary points
static func from_points(points: Array[Vector2], resolution: int = 1) -> FloorPlanGrid:
	assert(resolution>=1, "resoltion must be a natual number (e.g >= 1)")
	if points.is_empty():
		return null
	const padding: int = 1
	
	var bounds: Rect2 = _get_bounds(points)
	assert(bounds.is_finite(), "bounding box can't be infinite")
	var grid_size: Vector2 = snap2(bounds.end, 1.0/resolution)-snap2(bounds.position, 1.0/resolution) # get min grid dimension
	grid_size *= resolution # scale with resolution
	grid_size += Vector2.ONE*2*padding # add padding around the building grid

	
	var floor_grid: FloorPlanGrid = FloorPlanGrid.new(floor(grid_size).x, floor(grid_size).y, resolution)
	
	# Mark cells inside the polygon as empty, outside as OUTSIDE
	var origin: Vector2 = snap2(bounds.position, 1.0/resolution) - Vector2.ONE*padding/resolution
	var world_pos: Vector2
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			world_pos = origin + Vector2(x, y)/resolution
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


## generaterandom initial room placements
func place_rooms(rooms: Array[RoomArea]) -> void:
	_room_dict = {}
	print("rooms: ", rooms)

	var dist_grid: Array[Array] = _get_outside_dists() # should be Array[Array[int]]

	print("  dist_grid:")
	debug_print_mat2(dist_grid)
	
	var free_cells: int = 0
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			if get_cell(x,y).is_empty():
				free_cells += 1
	print("free_cells: ", free_cells)

	for room in rooms:
		print("------------------- room: ", rooms.find(room), " -------------------")
		var room_radius: int = floor(sqrt(room.rel_size*free_cells)/2)
		print("  room.rel_size: ", room.rel_size)
		print("  room_radius: ", room_radius)
		var entropy: Array[Array] = []
		
		# optimal wall distance
		for y in range(dist_grid.size()):
			var row: Array[int] = []
			for x in range(dist_grid[y].size()):
				if dist_grid[y][x]<=0:
					row.append(-1)
				else:
					row.append(abs(room_radius-dist_grid[y][x]))
			entropy.append(row)
		
		print("  entropy_grid:")
		debug_print_mat2(entropy)
		
		# TODO: do other calculations
		#   - distance from other rooms
		#   - neighbor constraints
		
		# select random from minimum
		var entropy_flattend: Array[int] = []
		for row in entropy:
			entropy_flattend.append_array(row)
		entropy_flattend.sort()
		var min_entropy = entropy_flattend[entropy_flattend.find_custom(func (x): return x>=0)]
		print("  min_entropy: ", min_entropy)
		
		var valid_cells: Array[Vector2i] = []
		for y in range(len(entropy)):
			for x in range(len(entropy[y])):
				if entropy[y][x] == min_entropy:
					valid_cells.append(Vector2i(x, y))
		assert(not valid_cells.is_empty(), "valid_cells shouldn't be empty")
		var random_cell: Vector2i = valid_cells[randi()%valid_cells.size()]
		var initial_room_cell: FloorPlanCell = get_cell(random_cell.x, random_cell.y)
		assert(initial_room_cell.is_empty(), "selected cell should be empty")
		initial_room_cell.grow(room.id)
		_room_dict[random_cell] = room


func grow_rooms() -> void:
	# TODO: implement Room expansion algorithm
	pass


func _get_outside_dists() -> Array[Array]:
	var dist_grid: Array[Array] = _create_int_grid(-1)  # -1 means unvisited
	var queue: Array[Vector2i] = []
	
	# Initialize: add all outside cells to queue with distance 0
	for y in range(height):
		for x in range(width):
			if get_cell(x, y).is_outside():
				dist_grid[y][x] = 0
				queue.append(Vector2i(x, y))
	
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),   # right
		Vector2i(-1, 0),  # left
		Vector2i(0, 1),   # down
		Vector2i(0, -1)   # up
	]
	# BFS to calculate distances
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		var current_dist: int = dist_grid[pos.y][pos.x]
		
		# Check all neighbors
		for dir in directions:
			var nx: int = pos.x + dir.x
			var ny: int = pos.y + dir.y
			
			# Skip if out of bounds or already visited
			if nx < 0 or nx >= width or ny < 0 or ny >= height:
				continue
			if dist_grid[ny][nx] != -1:
				continue
			
			# Set distance and add to queue
			dist_grid[ny][nx] = current_dist + 1
			queue.append(Vector2i(nx, ny))
	
	return dist_grid


func get_rooms() -> Array[int]:
	var rooms: Array[int] = []
	for y in range(height):
		for x in range(width):
			var cell: FloorPlanCell = get_cell(x, y)
			if not cell.is_empty() and not cell.is_outside() and cell.room_id not in rooms:
				rooms.append(cell.room_id)
	rooms.sort()
	return rooms


func to_texture() -> Image:
	var rooms: Array[int] = get_rooms()
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGB8)
	for y in range(height):
		for x in range(width):
			var cell: FloorPlanCell = get_cell(x, y)
			if cell.is_outside():
				image.set_pixel(x, y, Color.from_rgba8(35, 39, 46))
			elif cell.is_empty():
				image.set_pixel(x, y, Color.from_rgba8(255, 0, 255))
			else:
				var hue: float = rooms.find(cell.room_id)/float(rooms.size())
				image.set_pixel(x, y, Color.from_ok_hsl(hue, 66/100.0, 55/100.0))
	return image


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

## Debug: Print grid
func debug_print_mat2(mat2: Array[Array]) -> void:
	for y: int in range(mat2.size()):
		var row_str: String = ""
		for x: int in range(mat2[y].size()):
			if mat2[y][x] == -1:
				row_str += "- "
			else:
				row_str += str(mat2[y][x]) + " "
		print(row_str)
