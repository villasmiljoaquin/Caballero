extends Control

#Lleva al nivel 1
const ESCENA_NIVEL_1 = "res://Niveles/Nivel1.tscn"

@onready var btn_nivel_1: Button = $VBoxContainer/BtnNivel1
@onready var btn_nivel_2: Button = $VBoxContainer/BtnNivel2
@onready var btn_salir: Button = $VBoxContainer/BtnSalir


func _ready() -> void:
	#Reanuda el timepo
	Engine.time_scale = 1.0
	
	btn_nivel_1.pressed.connect(_on_btn_nivel_1_pressed)
	btn_salir.pressed.connect(_on_btn_salir_pressed)
	
	# Manejar por teclado
	btn_nivel_1.grab_focus()


func _on_btn_nivel_1_pressed() -> void:
	get_tree().change_scene_to_file(ESCENA_NIVEL_1)


func _on_btn_salir_pressed() -> void:
	get_tree().quit()
