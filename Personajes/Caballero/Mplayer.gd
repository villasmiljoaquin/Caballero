extends CharacterBody2D

# --- MOVIMIENTO HORIZONTAL ---
@export var velocidad: float = 850.0

# --- SALTO Y GRAVEDAD ---
@export var velocidad_salto: float = -2200.0
@export var gravedad_subida: float = 2600.0
@export var gravedad_caida: float = 4200.0
@export var velocidad_caida_max: float = 1300.0
@export var corte_salto: float = 0.45

# --- ASISTENCIAS DE CONTROL ---
@export var coyote_time: float = 0.10
@export var jump_buffer: float = 0.12

# --- DASH / PARRY Y ESTAMINA POR CARGAS (5 Dashes) ---
@export var velocidad_dash: float = 2600.0
@export var duracion_dash: float = 0.26
@export var cooldown_dash: float = 0.50
@export var tiempo_recarga_dash: float = 3.0 # Segundos que tarda en recuperar 1 carga

# --- LÍMITE DEL MUNDO ---
@export var limite_caida_y: float = 3000.0

# --- ESTADO Y VARIABLES ---
var vida_max: int = 6
var vida_actual: int = 6
var estamina_max: int = 5
var estamina_actual: int = 5
var monedas: int = 0

var timer_coyote: float = 0.0
var timer_buffer: float = 0.0
var haciendo_dash: bool = false
var animando_parry: bool = false
var invulnerable_parry: bool = false
var puede_dash: bool = true
var timer_dash: float = 0.0
var timer_cooldown_dash: float = 0.0
var timer_recarga_estamina: float = 0.0
var direccion_mirada: int = 1
var esta_muerto: bool = false
var invulnerable: bool = false

# --- REFERENCIAS DE NODOS HIJOS ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_parry: Area2D = $AreaParry
@onready var destello_parry: AnimatedSprite2D = get_node_or_null("DestelloParry")
@onready var sonido_salto: AudioStreamPlayer2D = $SonidoSalto
@onready var sonido_dano: AudioStreamPlayer2D = $SonidoDano
@onready var sonido_moneda: AudioStreamPlayer2D = $SonidoMoneda
@onready var sonido_dash: AudioStreamPlayer2D = $SonidoParry

# --- REFERENCIAS DE INTERFAZ (CanvasLayer) ---
@onready var barra_estamina: AnimatedSprite2D = get_node_or_null("../CanvasLayer/BarraEstamina")
@onready var barra_vida: AnimatedSprite2D = get_node_or_null("../CanvasLayer/BarraVida")
@onready var label_monedas: Label = get_node_or_null("../CanvasLayer/ContadorMonedas/LabelMonedas")

func _ready() -> void:
	add_to_group("personaje")
	add_to_group("jugador")
	estamina_actual = estamina_max
	vida_actual = vida_max
	sprite.play("idle")
	
	if area_parry:
		area_parry.monitoring = false
		if not area_parry.area_entered.is_connected(_on_area_parry_entered):
			area_parry.area_entered.connect(_on_area_parry_entered)
		if not area_parry.body_entered.is_connected(_on_body_parry_entered):
			area_parry.body_entered.connect(_on_body_parry_entered)
	if destello_parry:
		destello_parry.visible = false
	
	if barra_estamina:
		barra_estamina.stop()
		barra_estamina.frame = estamina_actual
	if barra_vida:
		barra_vida.stop()
		barra_vida.frame = vida_actual
	if label_monedas:
		label_monedas.text = str(monedas)
		
	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	if esta_muerto:
		velocity.x = 0
		aplicar_gravedad(delta)
		move_and_slide()
		return

	# Comprobar caída al vacío (en Godot Y aumenta hacia abajo)
	if global_position.y > limite_caida_y:
		morir()
		return

	actualizar_timers(delta)
	regenerar_estamina(delta)
	
	# 1. Lógica del Dash / Parry
	if haciendo_dash:
		velocity.x = direccion_mirada * velocidad_dash
		velocity.y = 0.0
		move_and_slide()
		return

	# 2. Movimiento horizontal inmediato
	var dir_input := Input.get_axis("ui_left", "ui_right")
	if dir_input != 0:
		velocity.x = dir_input * velocidad
		direccion_mirada = sign(dir_input)
		sprite.flip_h = direccion_mirada > 0
		if area_parry:
			area_parry.scale.x = direccion_mirada
		if destello_parry:
			destello_parry.position.x = abs(destello_parry.position.x) * direccion_mirada
			destello_parry.flip_h = direccion_mirada > 0
	else:
		velocity.x = 0.0

	# 3. Iniciar Dash / Parry
	if Input.is_action_just_pressed("parrykey") and puede_dash and timer_cooldown_dash <= 0 and estamina_actual >= 1:
		iniciar_dash()
		return

	# 4. Gravedad asimétrica
	aplicar_gravedad(delta)

	# 5. Salto con Coyote Time y Jump Buffer
	if timer_buffer > 0 and timer_coyote > 0:
		velocity.y = velocidad_salto
		timer_buffer = 0.0
		timer_coyote = 0.0
		sonido_salto.play()

	# 6. Salto de altura variable
	if Input.is_action_just_released("ui_accept") and velocity.y < 0:
		velocity.y *= corte_salto

	move_and_slide()
	actualizar_animaciones(dir_input)

func aplicar_gravedad(delta: float) -> void:
	if not is_on_floor():
		var grav := gravedad_subida if velocity.y < 0 else gravedad_caida
		velocity.y = min(velocity.y + grav * delta, velocidad_caida_max)

func actualizar_timers(delta: float) -> void:
	if is_on_floor():
		timer_coyote = coyote_time
		puede_dash = true
	else:
		timer_coyote -= delta

	if Input.is_action_just_pressed("ui_accept"):
		timer_buffer = jump_buffer
	else:
		timer_buffer -= delta

	if haciendo_dash:
		timer_dash -= delta
		if timer_dash <= 0:
			terminar_dash()

	if timer_cooldown_dash > 0:
		timer_cooldown_dash -= delta

func regenerar_estamina(delta: float) -> void:
	if estamina_actual < estamina_max:
		timer_recarga_estamina += delta
		if timer_recarga_estamina >= tiempo_recarga_dash:
			timer_recarga_estamina = 0.0
			estamina_actual += 1
			if barra_estamina:
				barra_estamina.frame = estamina_actual
	else:
		timer_recarga_estamina = 0.0

func iniciar_dash() -> void:
	haciendo_dash = true
	animando_parry = true
	invulnerable_parry = true
	puede_dash = false
	timer_dash = duracion_dash
	timer_cooldown_dash = cooldown_dash
	
	if area_parry:
		area_parry.monitoring = true
	
	estamina_actual = max(estamina_actual - 1, 0)
	if barra_estamina:
		barra_estamina.frame = estamina_actual
	
	velocity.y = 0.0
	sonido_dash.play()
	sprite.play("parry")

func terminar_dash() -> void:
	haciendo_dash = false
	invulnerable_parry = false
	velocity.x = 0.0
	if area_parry:
		area_parry.monitoring = false

# --- DETECCIÓN Y DEVOLUCIÓN DE PROYECTILES ---
func _on_area_parry_entered(area: Area2D) -> void:
	if invulnerable_parry:
		devolver_proyectil(area)

func _on_body_parry_entered(body: Node2D) -> void:
	if invulnerable_parry and body != self:
		devolver_proyectil(body)

func devolver_proyectil(obj: Node2D) -> void:
	if obj.is_in_group("proyectil") and not obj.devuelta:
		obj.devuelta = true
		obj.direction = direccion_mirada
		obj.velocity = Vector2(direccion_mirada * obj.SPEED * 5.0, 0.0)
		if obj.has_node("Sprite2D"):
			obj.get_node("Sprite2D").flip_h = direccion_mirada < 0
		activar_destello_parry()

func activar_destello_parry() -> void:
	sonido_dash.play()
	if destello_parry:
		destello_parry.position.x = abs(destello_parry.position.x) * direccion_mirada
		destello_parry.flip_h = direccion_mirada > 0
		destello_parry.visible = true
		destello_parry.frame = 0
		destello_parry.play()
		await destello_parry.animation_finished
		destello_parry.visible = false

func _on_animation_finished() -> void:
	if sprite.animation == "parry":
		animando_parry = false

func actualizar_animaciones(dir_input: float) -> void:
	if invulnerable or haciendo_dash or animando_parry:
		return
		
	if dir_input != 0:
		if sprite.animation != "run" or not sprite.is_playing():
			sprite.play("run")
	else:
		if sprite.animation != "idle" or not sprite.is_playing():
			sprite.play("idle")

# --- DAÑO, MUERTE Y MONEDAS ---
func recibir_dano(_cantidad: int = 1) -> void:
	if invulnerable or invulnerable_parry or esta_muerto:
		return
		
	vida_actual = max(vida_actual - 1, 0)
	sonido_dano.play()
	
	if barra_vida:
		barra_vida.frame = vida_actual
		
	if vida_actual <= 0:
		morir()
	else:
		invulnerable = true
		animando_parry = false
		sprite.play("Hit")
		velocity = Vector2(-direccion_mirada * 450, -600)
		await get_tree().create_timer(0.6).timeout
		invulnerable = false

func morir() -> void:
	if esta_muerto:
		return
	esta_muerto = true
	haciendo_dash = false
	invulnerable_parry = false
	
	# Vacía vida y pierde todas las monedas
	vida_actual = 0
	if barra_vida:
		barra_vida.frame = 0
	monedas = 0
	if label_monedas:
		label_monedas.text = "0"
		
	sonido_dano.play()
	sprite.play("Dead")
	await get_tree().create_timer(1.2).timeout
	get_tree().reload_current_scene()

func sumar_moneda(valor: int = 1) -> void:
	monedas += valor
	sonido_moneda.play()
	if label_monedas:
		label_monedas.text = str(monedas)

func recoger_moneda(valor: int = 1) -> void:
	sumar_moneda(valor)
