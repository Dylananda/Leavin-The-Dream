class_name LlmClient
extends Node
## Cliente de chat contra un modelo de lenguaje por HTTP, sin bloquear el juego
## (cada petición es un HTTPRequest que avisa al terminar).
##
## Por defecto usa Ollama en el propio PC (`/api/chat`). Para cambiar de modelo o pasar a uno
## en la nube con una API compatible con OpenAI (`/v1/chat/completions`), crea `user://ia.cfg`
## (en %APPDATA%\Godot\app_userdata\Yonkiland\):
##
##     [ia]
##     proveedor="openai"
##     url="https://api.openai.com/v1/chat/completions"
##     modelo="gpt-4o-mini"
##     clave="..."        ; o la variable de entorno YONKILAND_IA_CLAVE
##
## Con proveedor="ollama" basta con poner otro `modelo` (p. ej. "llama3.1:8b").

const CONFIG_PATH := "user://ia.cfg"
## Valores por defecto de cada formato de API.
## (127.0.0.1 y no localhost: Godot prueba antes IPv6 y Ollama solo escucha en IPv4.)
const PROVEEDORES := {
	"ollama": {"url": "http://127.0.0.1:11434/api/chat", "modelo": "qwen2.5:7b"},
	"openai": {"url": "https://api.openai.com/v1/chat/completions", "modelo": "gpt-4o-mini"},
}
const TIMEOUT_S := 90.0  ## La primera respuesta tarda: Ollama tiene que cargar el modelo en la GPU
const TEMPERATURE := 0.7
const KEEP_ALIVE := "30m"  ## Cuánto deja Ollama el modelo cargado entre frases

var proveedor := "ollama"
var url := ""
var modelo := ""
var clave := ""
var timeout := TIMEOUT_S


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # la partida está en pausa mientras hablas
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		proveedor = cfg.get_value("ia", "proveedor", proveedor)
	if not PROVEEDORES.has(proveedor):
		proveedor = "ollama"
	url = cfg.get_value("ia", "url", PROVEEDORES[proveedor]["url"])
	modelo = cfg.get_value("ia", "modelo", PROVEEDORES[proveedor]["modelo"])
	clave = cfg.get_value("ia", "clave", OS.get_environment("YONKILAND_IA_CLAVE"))


## Nombre corto para los mensajes del registro.
func describe() -> String:
	return "%s (%s)" % [modelo, "Ollama local" if proveedor == "ollama" else url.get_slice("/", 2)]


## Manda la conversación `messages` ([{"role", "content"}]) y llama a `callback(ok, texto)`
## con la respuesta del modelo o con el error. `schema` es el JSON Schema que debe cumplir
## la respuesta (Ollama lo impone; las APIs tipo OpenAI solo garantizan que sea JSON).
func ask(messages: Array, schema: Dictionary, callback: Callable) -> void:
	var http := HTTPRequest.new()
	http.timeout = timeout
	http.use_threads = true  # si no, solo avanza una vez por frame y la respuesta tarda el triple
	add_child(http)
	var headers := ["Content-Type: application/json"]
	var body := {"model": modelo, "messages": messages}
	if proveedor == "ollama":
		body["stream"] = false
		body["format"] = schema if not schema.is_empty() else "json"
		body["options"] = {"temperature": TEMPERATURE}
		body["keep_alive"] = KEEP_ALIVE
	else:
		body["temperature"] = TEMPERATURE
		body["response_format"] = {"type": "json_object"}
		if clave != "":
			headers.append("Authorization: Bearer " + clave)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, raw: PackedByteArray):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS:
			callback.call(false, "no responde (%s)" % _result_text(result))
			return
		var text := raw.get_string_from_utf8()
		if code != 200:
			callback.call(false, "error %d: %s" % [code, text.left(200)])
			return
		var data = JSON.parse_string(text)
		var content := ""
		if data is Dictionary:
			if proveedor == "ollama":
				content = data.get("message", {}).get("content", "")
			elif not data.get("choices", []).is_empty():
				content = data["choices"][0].get("message", {}).get("content", "")
		if content == "":
			callback.call(false, "respuesta vacía o rara: %s" % text.left(200))
		else:
			callback.call(true, content))
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		callback.call(false, "no se pudo enviar la petición (error %d)" % err)


static func _result_text(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR:
			return "no hay nada escuchando; ¿está Ollama en marcha?"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "no se encuentra el servidor"
		HTTPRequest.RESULT_TIMEOUT:
			return "tarda demasiado"
	return "error de red %d" % result
