extends RefCounted
class_name FloorPlanGen

enum HouseZone {PUBLIC, PRIVATE, HALLWAY}
enum HouseSize {SMALL, NORMAL, LARGE}

var _building_outline: Array[Vector2] = []

var _outline_grid_resolution: int = 1
var _room_grid_resolution: int = 2 # maybe also try with 1

var _floorplan_grid: FloorPlanGrid

const _house_radius: Dictionary[int, float] = {
	HouseSize.SMAll  = 4,
	HouseSize.NORMAL = 6,
	HouseSize.LARGE  = 9,
}
const _randomness: Dictionary[int, float] = {
	HouseSize.SMALL  = 0.4,
	HouseSize.NORMAL = 0.6,
	HouseSize.LARGE  = 0.9,
}

func generate
