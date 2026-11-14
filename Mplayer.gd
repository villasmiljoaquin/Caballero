extends CharacterBody2D

const SPEED = 550.0
const JUMP_VELOCITY = -1450.0
const GRAVITY = 2600.0
const MAX_FALL_SPEED = 1100.0
const JUMP_CUT_MULTIPLIER = 0.25

const COYOTE_TIME = 0.10
const JUMP_BUFFER_TIME = 0.12

var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var vida := 100
var invulnerable := false

# Estados de animación y parry
var muerto := false
var recibiendo_golpe := false
var animando_parry := false
var parry_activo := false
var parry_cooldown := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var barra_vida: ProgressBar = get_node("../CanvasLayer/ProgressBar")
@onready var barra_dano: ProgressBar = get_node("../CanvasLayer/BarraDano")
@onready var area_parry: Area2D = $AreaParry
@onready var destello_parry: Sprite2D = $DestelloParry


func _ready() -> void:
	destello_parry.visible = false
	area_parry.area_entered.connect(_on_area_parry_entered)


func _physics_process(delta: float) -> void:
	# Si está muerto, detiene el movimiento horizontal y espera la animación Dead
	if muerto:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
		move_and_slide()
		return

	# 1. Gravedad con velocidad terminal
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta
		velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

	# 2. Jump Buffer
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	# 3. Salto con Coyote Time y Jump Buffer
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0.0
		jump_buffer_timer = 0.0

	if Input.is_action_just_released("ui_accept") and velocity.y < 0:
		velocity.y *= JUMP_CUT_MULTIPLIER

	# 4. Movimiento horizontal y orientación
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * SPEED
		sprite.flip_h = direction > 0
		area_parry.position.x = abs(area_parry.position.x) * direction
		destello_parry.position.x = abs(destello_parry.position.x) * direction
		destello_parry.flip_h = direction < 0
	else:
		velocity.x = 0.0

	# 5. Activar ventana de Parry
	if Input.is_action_just_pressed("parrykey") and not parry_cooldown:
		activar_parry()

	move_and_slide()
	actualizar_animaciones(direction)


func actualizar_animaciones(direction: float) -> void:
	if muerto:
		return
	if recibiendo_golpe:
		sprite.play("Hit")
		return
	if animando_parry:
		sprite.play("parry")
		return

	if direction != 0:
		sprite.play("run")
	else:
		sprite.play("idle")


func activar_parry() -> void:
	parry_activo = true
	parry_cooldown = true
	animando_parry = true
	sprite.play("parry")
	
	# Revisa si ya había un proyectil dentro del área justo al pulsar el botón
	for area in area_parry.get_overlapping_areas():
		if area.is_in_group("proyectil") and not area.get("devuelta"):
			ejecutar_impacto_parry(area)
			break

	# Ventana de 0.20s para atrapar el proyectil
	await get_tree().create_timer(0.20).timeout
	parry_activo = false
	
	# Espera a que termine la animación completa de parry antes de volver a idle/run
	if sprite.is_playing() and sprite.animation == "parry":
		await sprite.animation_finished
	animando_parry = false
	
	await get_tree().create_timer(0.15).timeout
	parry_cooldown = false


func _on_area_parry_entered(area: Area2D) -> void:
	if parry_activo and area.is_in_group("proyectil") and not area.get("devuelta"):
		ejecutar_impacto_parry(area)


func ejecutar_impacto_parry(proyectil: Area2D) -> void:
	parry_activo = false
	animando_parry = true
	sprite.play("parry")
	
	# Invierte ambos ejes y multiplica la velocidad por 5
	proyectil.devuelta = true
	proyectil.velocity = Vector2(-5.0 * proyectil.velocity.x, -5.0 * proyectil.velocity.y)
	proyectil.modulate = Color(1.5, 1.3, 0.4)
	
	if proyectil.has_node("Sprite2D"):
		var proj_sprite: Sprite2D = proyectil.get_node("Sprite2D")
		proj_sprite.flip_h = not proj_sprite.flip_h
	
	destello_parry.visible = true
	
	# Hitstop de 0.2s
	Engine.time_scale = 0.0
	await get_tree().create_timer(0.2, true, false, true).timeout
	Engine.time_scale = 1.0
	
	await get_tree().create_timer(0.25).timeout
	destello_parry.visible = false


func recibir_dano(cantidad: int) -> void:
	if invulnerable or parry_activo or muerto:
		return

	vida = max(vida - cantidad, 0)
	animar_barra_ultrakill(vida)

	if vida <= 0:
		muerto = true
		sprite.play("Dead")
		await sprite.animation_finished
		await get_tree().create_timer(0.3).timeout
		get_tree().reload_current_scene()
		return

	invulnerable = true
	recibiendo_golpe = true
	sprite.play("Hit")
	sprite.modulate = Color(1, 0.4, 0.4)
	
	await get_tree().create_timer(0.3).timeout
	recibiendo_golpe = false
	
	await get_tree().create_timer(0.3).timeout
	sprite.modulate = Color(1, 1, 1)
	invulnerable = false


func animar_barra_ultrakill(nueva_vida: int) -> void:
	barra_vida.value = nueva_vida

	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_property(barra_dano, "value", nueva_vida, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	var pos_original := barra_vida.position
	var shake := create_tween().set_parallel(true)
	shake.tween_property(barra_vida, "position", pos_original + Vector2(6, -4), 0.04)
	shake.tween_property(barra_dano, "position", pos_original + Vector2(6, -4), 0.04)
	shake.chain().tween_property(barra_vida, "position", pos_original + Vector2(-6, 4), 0.04)
	shake.parallel().tween_property(barra_dano, "position", pos_original + Vector2(-6, 4), 0.04)
	shake.chain().tween_property(barra_vida, "position", pos_original, 0.04)
	shake.parallel().tween_property(barra_dano, "position", pos_original, 0.04)
