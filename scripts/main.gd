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
	
	print(graph.to_dot("BaseGraph"))
	
	print(graph.get_mst().to_dot("MstGraph"))
