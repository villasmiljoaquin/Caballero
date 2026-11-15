extends Area2D

@export var valor := 1
var recogida := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if recogida:
		return
	if body.is_in_group("personaje"):
		recogida = true
		if body.has_method("sumar_moneda"):
			body.sumar_moneda(valor)
		queue_free()
