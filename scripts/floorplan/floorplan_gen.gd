extends RefCounted
class_name FloorPlanGen

enum HouseZone {PUBLIC, PRIVATE, HALLWAY}
enum HouseSize {SMALL, NORMAL, LARGE}
enum Direction {N=0, E=1, S=2, W=3}

const DIRECTION_VECTORS: Dictionary[Direction, Vector2] = {
	Direction.N: Vector2.UP,
	Direction.E: Vector2.RIGHT,
	Direction.S: Vector2.DOWN,
	Direction.W: Vector2.LEFT,
}
const VECTOR_DIRECTIONS: Dictionary[Vector2, Direction] = {
	Vector2.UP: Direction.N,
	Vector2.RIGHT: Direction.E,
	Vector2.DOWN: Direction.S,
	Vector2.LEFT: Direction.W
}

var building_outline: Array[Vector2] = []


var _seed: int = -1

# values to snap all vectors to
var _outline_grid_resolution: float = 1
var _room_grid_resolution: float =  0.5 # maybe also try with 1

var _floorplan_grid: FloorPlanGrid

const _initial_vertecies: Dictionary[HouseSize, int] = {
	HouseSize.SMALL:  3,
	HouseSize.NORMAL: 6,
	HouseSize.LARGE:  11,
}
const _randomness: Dictionary[HouseSize, float] = {
	HouseSize.SMALL:  0.4,
	HouseSize.NORMAL: 0.6,
	HouseSize.LARGE:  0.9,
}
const _house_radius: Dictionary[HouseSize, float] = {
	HouseSize.SMALL:  4,
	HouseSize.NORMAL: 6,
	HouseSize.LARGE:  9,
}

func _init(grid_resolution:float = 1, grid_subdivisions: int = 2) -> void:
	assert(grid_resolution>0, "grid resolution must be a positive value")
	_outline_grid_resolution = 1/grid_resolution
	_room_grid_resolution = grid_resolution/grid_subdivisions

## Returns a random floating point-value between `min_value` and `1.0` (inclusive) 
static func randf_min(min_value: float) -> float:
	min_value = clamp(min_value, 0, 1)
	return randf()*min_value+(1-min_value)

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

	var output_dir: Direction
	if incoming_dir == -1:
		@warning_ignore("integer_division") 
		output_dir = (invalid_dir+len(Direction)/2)%len(Direction) as Direction
	else:
		output_dir = randi_range(0, len(Direction)-1) as Direction
	# flip direction if it is invalid
	if output_dir == invalid_dir:
		@warning_ignore("integer_division") 
		output_dir = (output_dir+len(Direction)/2)%len(Direction)  as Direction
	if invalid_dir_2!=invalid_dir and output_dir == invalid_dir_2:
		@warning_ignore("integer_division") 
		output_dir = (output_dir+len(Direction)/2)%len(Direction)  as Direction
		
	# if selected output direction is the input direction rotate input clockwise untill not inside the invalid_dir
	@warning_ignore("integer_division") 
	if incoming_dir != -1 and output_dir == (incoming_dir+len(Direction)/2)%len(Direction):
		# assert(len(Direction)>=3, "Need at least 3 directions or this might be a `while true:` loop")
		while true:
			output_dir = (output_dir+1)%len(Direction) as Direction
			@warning_ignore("integer_division") 
			if output_dir!=invalid_dir and output_dir!=invalid_dir_2 and output_dir!=(incoming_dir+len(Direction)/2)%len(Direction):
				break
	
	return output_dir

func _get_connection_points(point_a: Vector2, point_b: Vector2, start_direction: Vector2) -> Array[Vector2]:
	# cheack weather the connection needs zero, one or two intermediate points and return them
	if is_equal_approx(point_a.x, point_b.x) or is_equal_approx(point_a.y, point_b.y):
		return []
	elif start_direction.x*(point_b.x-point_a.x) > 0 or start_direction.y*(point_b.y-point_a.y) > 0:
		return [
			Vector2(
				point_a + Vector2((point_b.x-point_a.x) * abs(start_direction.x),
				(point_b.y-point_a.y) * abs(start_direction.y))
			)
		]
	else:
		var result: Array[Vector2] = [Vector2(point_a - Vector2((point_b.x-point_a.x) * abs(start_direction.x),
			(point_b.y-point_a.y) * abs(start_direction.y))
		)]
		result.append(2*result[0]+point_b-2*point_a	)
		return result

func _generatebuilding_outline(vertices: int = 7, randomness: float = 0.8, radius: float = 5) -> Array[Vector2]:
	var dists: Array[float] = [0]
	var total_dist: float = 0
	for i in range(1, vertices):
		dists.append(dists[-1]+randf_min(randomness))
	total_dist = dists[-1]+randf_min(randomness)
	
	var points: Array[Vector2] = []
	for point in dists:
		points.append((Vector2.from_angle(point/total_dist*2*PI) * radius).snapped(Vector2.ONE*_outline_grid_resolution))
	var result: Array[Vector2] = []
	var incoming_dir: int = -1
	
	for i in range(points.size()):
		var point_a = points[i]
		var point_b = points[(i + 1) % points.size()]
		
		result.append(point_a)
		
		# Base direction on vector to next point
		var vec_to_next = (point_b - point_a)
		if vec_to_next.is_zero_approx():
			print('ERROR POINTS ARE IDENTICAL')
			vec_to_next = Vector2.UP # Default if points are the same
			
		var travel_dir: Direction = _get_rand_valid_travel_direction(point_a, incoming_dir)
		var travel_vec: Vector2 = DIRECTION_VECTORS[travel_dir]
		
		result.append_array(_get_connection_points(point_a, point_b, travel_vec))
		
		var incoming_vec: Vector2 = points[(i+1)%len(points)]-result[-1]
		incoming_vec = incoming_vec.normalized()
		if incoming_vec.is_equal_approx(Vector2.ZERO):
			incoming_dir = -1
		else:
			incoming_dir = VECTOR_DIRECTIONS[incoming_vec]
	
	return result


## Sets the seed for the random number generator to `base`.
## A value of `-1` means no seed
func set_seed(base: int = -1) -> void:
	_seed = base
	seed(4)

## Generates a new floor plan for a predefined building size
func generate(size: HouseSize) -> void:
	generate_custom(
		_initial_vertecies[size],
		_randomness[size],
		_house_radius[size],
	)

## Generates a new floor plan for a custom building.
func generate_custom(initial_vertecies: int = 6, randomness: float = 0.6, radius: float = 6) -> void:
	if _seed == -1:
		randomize()
	else:
		seed(_seed)
	
	building_outline = _generatebuilding_outline(
		initial_vertecies,
		randomness,
		radius,
	)
	
	_floorplan_grid = FloorPlanGrid.from_points(building_outline)


class RoomArea extends RefCounted:
	var id: int = 0
	var zone: HouseZone = HouseZone.PUBLIC
	var rel_size: float = 1 # size ratio
	var connectivity: Array[int] = []
	
	@warning_ignore("shadowed_variable")
	func _init(id: int, zone: HouseZone, rel_size: float, connectivity: Array[int]) -> void:
		self.id = id
		self.zone = zone
		self.rel_size = rel_size
		self.connectivity = connectivity
	
	static func from_graph(graph: Graph, randomness:float = 1, _seed:int = -1) -> Array[RoomArea]:
		if _seed == -1:
			randomize()
		else:
			seed(_seed)
		
		var sizes: Array[float] = [0]
		for i in range(1, graph.nodes.size()):
			sizes.append(sizes[-1]+FloorPlanGen.randf_min(randomness))
		var total_size: float =  sizes[-1]+FloorPlanGen.randf_min(randomness)
		
		var result: Array[RoomArea] = []
		var random_zone: HouseZone
		var generated_hallway: bool = false # to ensure generation of maxiumum one hallway
		for i in range(graph.nodes.size()):
			if not generated_hallway:
				random_zone = randi()%HouseZone.size() as HouseZone
			else:
				random_zone = randi()%(HouseZone.size()-1) as HouseZone
				# this won't be needed, since `HALLWAY` is the last enum value
				#if random_zone == HouseZone.HALLWAY:
					#random_zone = random_zone+1 as HouseZone
			result.append(RoomArea.new(
				graph.nodes[i],
				random_zone,
				sizes[i]/total_size,
				graph.get_connections_from(graph.nodes[i])
			))
		
		return result
