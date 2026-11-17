extends SceneTree
func _init():
	var ps: PackedScene = load("res://assets/humans/raja.glb")
	var n = ps.instantiate()
	var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
	for b in ["root", "pelvis", "spine_01", "thigh_l", "calf_l", "foot_l", "ball_l", "thigh_r", "upperarm_l", "lowerarm_l", "hand_l", "clavicle_l", "head", "neck_01"]:
		var i := sk.find_bone(b)
		if i < 0:
			print(b, " missing"); continue
		var p := sk.get_bone_parent(i)
		print(b, " parent=", sk.get_bone_name(p) if p >= 0 else "-", " rest=", sk.get_bone_global_rest(i).origin, " rot=", sk.get_bone_rest(i).basis.get_euler())
	print("skel xform ", sk.transform, " parent ", sk.get_parent().name, " ", sk.get_parent().transform)
	quit()
