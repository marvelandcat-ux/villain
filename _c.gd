extends Node
func _ready():
	var s = load("res://maps/Playground.tscn").instantiate()
	add_child(s)
	await get_tree().process_frame
	var names = []
	for n in s.get_children():
		if n.name.begins_with("Pavilion"): names.append(n.name)
	print("[미끄럼틀 관련 노드] ", names)
	get_tree().quit()
