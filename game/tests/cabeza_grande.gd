extends SkeletonModifier3D
## (Pruebas de estilo) Agranda la cabeza y las manos de un esqueleto después de la animación,
## para que un modelo de proporciones adultas se lea bien desde la cámara del juego.

var cabeza := 1.35
var manos := 1.2


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i).to_lower()
		var s := 0.0
		if n.ends_with("head") or n == "head":
			s = cabeza
		elif n.ends_with("hand") or n.ends_with("hand.l") or n.ends_with("hand.r") or n.begins_with("hand"):
			s = manos
		if s > 0.0:
			sk.set_bone_pose_scale(i, sk.get_bone_pose_scale(i) * s)
