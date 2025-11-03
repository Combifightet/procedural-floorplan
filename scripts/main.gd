extends Node

var graph: Graph
var floorplan_gen: FloorPlanGen # Store this to access grid later if needed

@onready var debug_rect: ColorRect = $ColorRect

func _ready() -> void:
	# ... (all your existing graph and floorplan setup code) ...
	
	graph = Graph.get_connected(7, true, 1)
	
	print(graph.to_dot("RandomGraph"))
	var mst_graph: Graph = graph.get_mst()
	mst_graph._is_dirceted=true
	print(mst_graph.to_dot("MstGraph"))
	
	print("")
	
	floorplan_gen = FloorPlanGen.new(1, 2) # Assign to class variable
	# without a seed it's not repeatable
	floorplan_gen.set_seed(7)
	#randomize()
	#floorplan_gen.set_seed(randi())
	floorplan_gen.generate(FloorPlanGen.HouseSize.NORMAL)
	print("last_seed: ", floorplan_gen.get_last_seed())

	print("displaying grid ...")
	var grid: FloorPlanGrid = floorplan_gen.get_grid()
	var texture: ImageTexture = ImageTexture.create_from_image(grid.to_texture())
	
	debug_rect.material.set_shader_parameter('data_texture', texture)
	debug_rect.material.set_shader_parameter('data_size', Vector2(grid.width, grid.height))
	debug_rect.material.set_shader_parameter('container_size', debug_rect.size)
	debug_rect.resized.connect(_on_debug_rect_resized)

# Updates the 'container_size' uniform whenever the ColorRect is resized
func _on_debug_rect_resized() -> void:
	if debug_rect.material: # Check if material exists
		debug_rect.material.set_shader_parameter('container_size', debug_rect.size)
