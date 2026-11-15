extends Area2D

# Te permite arrastrar o seleccionar el archivo .tscn del siguiente nivel en el Inspector
@export_file("*.tscn") var siguiente_nivel: String

var activado: bool = false

func _on_body_entered(body: Node2D) -> void:
	# Verifica que sea el jugador y evita que se ejecute dos veces seguidas
	if body.is_in_group("jugador") and not activado:
		activado = true
		# call_deferred evita errores de físicas al cambiar de escena en medio de una colisión
		cambiar_nivel.call_deferred()

func cambiar_nivel() -> void:
	if siguiente_nivel != "":
		get_tree().change_scene_to_file(siguiente_nivel)
	else:
		push_warning("No asignaste ninguna escena en 'siguiente_nivel' para este portal.")
