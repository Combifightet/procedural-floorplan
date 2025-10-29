extends RefCounted
class_name FloorPlanGrid

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
func place_rooms(rooms: Array[RoomArea]):
	# TODO: implement algorithm
	pass


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
