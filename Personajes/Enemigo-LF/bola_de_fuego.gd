extends Area2D

const SPEED = 550.0
var direction := 1
var velocity := Vector2.ZERO
var devuelta := false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("proyectil")
	sprite.flip_h = direction < 0
	velocity = Vector2(direction * SPEED, 0.0)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += velocity * delta

func _on_body_entered(body: Node2D) -> void:
	if not devuelta and body.is_in_group("jugador"):
		body.recibir_dano(20)
		queue_free()
	elif devuelta and body.is_in_group("enemigo"):
		if body.has_method("recibir_dano"):
			body.recibir_dano(50)
		else:
			body.queue_free()
		queue_free()
	elif body is TileMapLayer:
		queue_free()
