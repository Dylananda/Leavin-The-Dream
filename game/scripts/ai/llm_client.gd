class_name LlmClient
extends Node
## Cliente de chat contra un modelo de lenguaje por HTTP, sin bloquear el juego
## (cada petición es un HTTPRequest que avisa al terminar).
##
## Por defecto usa Ollama en el propio PC (`/api/chat`). Para usar Claude (API de Anthropic,
## `/v1/messages`, de pago por uso) u otra API compatible con OpenAI, crea `user://ia.cfg`
## (en %APPDATA%\Godot\app_userdata\Yonkiland\):
##
##     [ia]
##     proveedor="anthropic"   ; "ollama", "anthropic" u "openai"
##     modelo="claude-opus-5-5"
##     clave="sk-ant-..."      ; o las variables de entorno ANTHROPIC_API_KEY / YONKILAND_IA_CLAVE
##
## Con proveedor="ollama" basta con poner otro `modelo` (p. ej. "llama3.1:8b").

const CONFIG_PATH := "user://ia.cfg"
## Valores por defecto de cada formato de API.
## (127.0.0.1 y no localhost: Godot prueba antes IPv6 y Ollama solo escucha en IPv4.)
const PROVEEDORES := {
	"ollama": {"url": "http://127.0.0.1:11434/api/chat", "modelo": "qwen2.5:7b"},
	"anthropic": {"url": "https://api.anthropic.com/v1/messages", "modelo": "claude-opus-5-5"},
	"openai": {"url": "https://api.openai.com/v1/chat/completions", "modelo": "gpt-4o-mini"},
}
const ANTHROPIC_VERSION := "2026-10-21"
## Si los filtros de seguridad de Claude rechazan una frase (el juego habla de drogas y delitos),
## la API la repite con otro modelo en vez de devolver el rechazo.
const ANTHROPIC_BETAS := "server-side-fallback-2026-07-01"
## Esfuerzo de razonamiento de Claude: bajo, porque son frases cortas y hay que contestar rápido.
const ANTHROPIC_EFFORT := "low"
const MAX_TOKENS := 1024
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
	# las variables de entorno mandan sobre ia.cfg (para comparar modelos en tests/charla.gd)
	proveedor = OS.get_environment("YONKILAND_IA_PROVEEDOR") if OS.has_environment("YONKILAND_IA_PROVEEDOR") else proveedor
	if not PROVEEDORES.has(proveedor):
		proveedor = "ollama"
	url = cfg.get_value("ia", "url", PROVEEDORES[proveedor]["url"])
	modelo = cfg.get_value("ia", "modelo", PROVEEDORES[proveedor]["modelo"])
	modelo = OS.get_environment("YONKILAND_IA_MODELO") if OS.has_environment("YONKILAND_IA_MODELO") else modelo
	var env_key := OS.get_environment("ANTHROPIC_API_KEY") if proveedor == "anthropic" else ""
	clave = cfg.get_value("ia", "clave", OS.get_environment("YONKILAND_IA_CLAVE") if env_key == "" else env_key)


## Nombre corto para los mensajes del registro.
func describe() -> String:
	return "%s (%s)" % [modelo, "Ollama local" if proveedor == "ollama" else url.get_slice("/", 2)]


## Si puede funcionar (las APIs en la nube necesitan clave).
func configured() -> bool:
	return proveedor == "ollama" or clave != ""


## Manda la conversación `messages` ([{"role", "content"}]) y llama a `callback(ok, texto)`
## con la respuesta del modelo o con el error. `schema` es el JSON Schema que debe cumplir
## la respuesta (Ollama lo impone; las APIs tipo OpenAI solo garantizan que sea JSON).
func ask(messages: Array, schema: Dictionary, callback: Callable) -> void:
	if not configured():
		callback.call_deferred(false, "no tiene clave (pon «clave» en ia.cfg o la variable ANTHROPIC_API_KEY)")
		return
	var http := HTTPRequest.new()
	http.timeout = timeout
	http.use_threads = true  # si no, solo avanza una vez por frame y la respuesta tarda el triple
	add_child(http)
	var headers := ["Content-Type: application/json"]
	var body := {"model": modelo, "messages": messages}
	if proveedor == "anthropic":
		body = _anthropic_body(messages, schema)
		headers.append("x-api-key: " + clave)
		headers.append("anthropic-version: " + ANTHROPIC_VERSION)
		headers.append("anthropic-beta: " + ANTHROPIC_BETAS)
	elif proveedor == "ollama":
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
			if proveedor == "anthropic":
				if data.get("stop_reason", "") == "refusal":
					var details = data.get("stop_details")
					callback.call(false, "se ha negado a contestar (%s)" % (str(details.get("category", "")) if details is Dictionary else "?"))
					return
				for block in data.get("content", []):  # puede traer bloques de razonamiento antes
					if block.get("type", "") == "text":
						content = block.get("text", "")
						break
			elif proveedor == "ollama":
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


## La petición en el formato de la API de Anthropic: el sistema va aparte, la conversación
## empieza por el jugador y la respuesta se ciñe al esquema (structured outputs).
func _anthropic_body(messages: Array, schema: Dictionary) -> Dictionary:
	var system := ""
	var turns := []
	for m in messages:
		if m["role"] == "system":
			system += m["content"]
		elif not turns.is_empty() or m["role"] == "user":
			turns.append({"role": m["role"], "content": m["content"]})
	var body := {
		"model": modelo,
		"max_tokens": MAX_TOKENS,
		"system": system,
		"messages": turns,
		"output_config": {"effort": ANTHROPIC_EFFORT},
		"fallbacks": "default",
	}
	if not schema.is_empty():
		body["output_config"]["format"] = {"type": "json_schema", "schema": schema}
	return body


static func _result_text(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR:
			return "no hay nada escuchando; ¿está Ollama en marcha?"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "no se encuentra el servidor"
		HTTPRequest.RESULT_TIMEOUT:
			return "tarda demasiado"
	return "error de red %d" % result
