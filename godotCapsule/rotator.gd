extends MeshInstance

export var axis = Vector3(0.0, 0.6, 0.8)

func _process(delta):
    transform.basis = Basis(axis, delta) * transform.basis
