extends Node

var graph: Graph

func _ready() -> void:
	graph = Graph.new(false) # undirected graph
	graph.nodes = [1, 2, 3, 4]
	graph.edges = [
		Graph.Edge.new(1, 2, 2),
		Graph.Edge.new(1, 3, 1),
		Graph.Edge.new(2, 3, 2),
		Graph.Edge.new(3, 4, 3),
	]
	
	graph = Graph.get_connected(7, true, 1)
	
	print(graph.to_dot("RandomGraph"))
	var mst_graph: Graph = graph.get_mst()
	mst_graph._is_dirceted=true
	print(mst_graph.to_dot("MstGraph"))
	
	print("")
	
	var floorplan_gen: FloorPlanGen = FloorPlanGen.new(1, 2)
	floorplan_gen.set_seed(2508830588)
	floorplan_gen.generate(FloorPlanGen.HouseSize.SMALL)
