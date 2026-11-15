extends CharacterBody2D

const SPEED = 140.0
const FIREBALL_SCENE = preload("res://Personajes/Enemigo-LF/bola de fuego.tscn")
const COOLDOWN_DISPARO = 3.2

var direction := 1
var jugador_cerca: Node2D = null
var tiempo_disparo := 0.8
var tiempo_giro := 0.0  # <-- Anti-bucle: impide girar más de una vez cada 0.25s

@onready var sprite: Sprite2D = $Sprite2D
@onready var detector_suelo: RayCast2D = $DetectorSuelo
@onready var zona_ataque: Area2D = $ZonaAtaque
@onready var zona_dano: Area2D = $ZonaDano


func _ready() -> void:
	add_to_group("enemigo")
	zona_ataque.body_entered.connect(_on_zona_ataque_entered)
	zona_ataque.body_exited.connect(_on_zona_ataque_exited)
	zona_dano.body_entered.connect(_on_zona_dano_entered)
	actualizar_orientacion()


func _physics_process(delta: float) -> void:
	if tiempo_giro > 0.0:
		tiempo_giro -= delta

	if not is_on_floor():
		velocity += get_gravity() * delta

	if jugador_cerca != null:
		velocity.x = 0
		direction = 1 if jugador_cerca.global_position.x > global_position.x else -1
		actualizar_orientacion()
		
		tiempo_disparo -= delta
		if tiempo_disparo <= 0.0:
			disparar()
			tiempo_disparo = COOLDOWN_DISPARO
	else:
		tiempo_disparo = 0.8
		if is_on_floor() and tiempo_giro <= 0.0:
			if is_on_wall() or not detector_suelo.is_colliding():
				direction *= -1
				actualizar_orientacion()
				tiempo_giro = 0.25
		velocity.x = direction * SPEED

	move_and_slide()


func actualizar_orientacion() -> void:
	sprite.flip_h = direction < 0
	detector_suelo.position.x = abs(detector_suelo.position.x) * direction
	detector_suelo.force_raycast_update()


func disparar() -> void:
	var bola = FIREBALL_SCENE.instantiate()
	bola.direction = direction
	# Usa sprite.global_position para alinearlo con el cuerpo visual de la tortuga
	bola.global_position = sprite.global_position + Vector2(60 * direction, -100)
	get_parent().add_child(bola)

func _on_zona_ataque_entered(body: Node2D) -> void:
	if body.is_in_group("jugador"):
		jugador_cerca = body


func _on_zona_ataque_exited(body: Node2D) -> void:
	if body == jugador_cerca:
		jugador_cerca = null


func _on_zona_dano_entered(body: Node2D) -> void:
	if body.is_in_group("jugador"):
		body.recibir_dano(25)
