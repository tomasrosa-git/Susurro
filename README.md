# Susurro

Dictado por voz para todo macOS. Mantené apretada una tecla, hablá, soltá: el texto aparece donde
esté el cursor, en cualquier app. Corre en la barra de menú, transcribe localmente con
[whisper.cpp](https://github.com/ggml-org/whisper.cpp) y funciona sin conexión. Opcionalmente pasa
el texto por un LLM que saca muletillas y arregla la puntuación. Sin cuentas ni telemetría.

## Requisitos

- macOS 14 o posterior, Apple Silicon recomendado (whisper.cpp usa Metal).
- Xcode o Command Line Tools (`xcode-select --install`).
- whisper.cpp y un modelo:

```bash
brew install whisper-cpp
mkdir -p ~/Library/Application\ Support/Susurro/models
curl -L -o ~/Library/Application\ Support/Susurro/models/ggml-small.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin
```

`small` (~470 MB) es el default. Para más precisión, bajá `ggml-medium.bin` (~1,5 GB) y poné
`"whisperModel": "medium"` en la configuración.

## Instalar

```bash
scripts/install.sh
```

Compila, instala en `~/Applications/Susurro.app` (aparece en Launchpad y Spotlight) y la abre. Si
ya estaba abierta, la reemplaza. Susurro no se abre sola al iniciar sesión; si querés que lo haga,
agregala en **Ajustes del Sistema → General → Ítems de inicio**.

Para desarrollo: `scripts/build-app.sh` deja la app en `build/Susurro.app` sin instalarla y
`scripts/test.sh` corre los tests. El ícono se genera con `scripts/make-icon.sh` a partir de
`scripts/make-icon.swift`.

## Permisos

Susurro necesita dos permisos en **Ajustes del Sistema → Privacidad y seguridad**:

| Permiso | Para qué | Cuándo se pide |
| --- | --- | --- |
| **Accesibilidad** | Escuchar el atajo global y simular ⌘V para pegar el texto | Al abrir la app por primera vez. Activá Susurro en la lista; no hace falta reiniciarla. |
| **Micrófono** | Grabar mientras mantenés el atajo | La primera vez que usás el atajo. |

Si macOS también lista a Susurro en **Monitoreo de entrada**, activalo: algunas versiones lo piden
además de Accesibilidad para leer el teclado.

Mientras falte Accesibilidad, el menú de Susurro muestra "⚠︎ Falta permiso de Accesibilidad…", que
abre directo el panel correspondiente.

### La tecla fn / 🌐

Si usás `fn` como atajo, en **Ajustes del Sistema → Teclado** poné "Al presionar la tecla 🌐" en
**No hacer nada**. Si no, macOS abre el selector de emoji o su propio dictado cada vez que la
soltás.

Algunos teclados externos no le envían la tecla fn a macOS; con esos usá una combinación (ver abajo).

### Permisos que se pierden al recompilar

macOS asocia los permisos a la firma del binario. `build-app.sh` firma ad-hoc por defecto, y esa
firma cambia en cada build, así que después de recompilar hay que sacar y volver a agregar Susurro en
Accesibilidad. Para evitarlo, creá una identidad de firma propia una sola vez:

1. Abrí **Acceso a Llaveros → Asistente para certificados → Crear un certificado**.
2. Nombre `Susurro Dev`, tipo de identidad **Raíz autofirmada**, tipo de certificado **Firma de
   código**.
3. Listo: `build-app.sh` e `install.sh` la usan solos cuando existe. Para firmar con otra identidad,
   pasala en `SUSURRO_SIGN_IDENTITY`.

La primera vez que firma con el certificado nuevo, macOS puede pedir la contraseña del llavero:
elegí **Permitir siempre**. Después de esa instalación hay que volver a dar Accesibilidad una última
vez; de ahí en adelante se mantiene.

## Configuración

`~/.config/susurro/config.json` (se crea con los defaults al primer arranque; el menú tiene
"Abrir configuración…" y "Recargar configuración"):

```json
{
  "cleanup" : true,
  "cleanupModel" : "qwen/qwen3.8-27b",
  "hotkey" : "fn",
  "language" : "auto",
  "restoreClipboard" : false,
  "transcriber" : "local",
  "whisperCLI" : "/opt/homebrew/bin/whisper-cli",
  "whisperModel" : "small"
}
```

Si actualizás Susurro y aparecen opciones nuevas, se agregan solas al archivo con su valor por defecto.

- **`hotkey`**: `fn`, o una combinación como `ctrl+option+space`, `cmd+shift+d` o `f13`. Modificadores:
  `ctrl`, `option`/`alt`, `shift`, `cmd`. Teclas: letras, números, `space`, `return`, `tab`,
  `delete`, `f1`–`f19`. Salvo `f13`–`f19`, una combinación necesita al menos un modificador. La
  combinación queda reservada para Susurro: no le llega a la app activa.
- **`language`**: `auto` para detectar el idioma, o un código como `es` o `en`. Fijarlo mejora la
  precisión en frases cortas.
- **`transcriber`**: `local` (whisper.cpp, sin conexión), `groq` (`whisper-large-v3-turbo`) u `openai`
  (`whisper-1`). Las opciones en la nube necesitan su key en `.env`; si falta, Susurro avisa en el menú
  y usa whisper local.
- **`whisperModel`**: `small`, `medium` (busca `ggml-<nombre>.bin` en
  `~/Library/Application Support/Susurro/models/`) o una ruta absoluta a cualquier modelo ggml. Solo
  aplica a `local`.
- **`whisperCLI`**: ruta a `whisper-cli`.
- **`cleanup`**: pasa el transcript por un LLM de Groq que saca muletillas ("eh", "este", "o sea"),
  repeticiones y arranques en falso, y arregla puntuación y mayúsculas sin cambiar lo que dijiste.
  Necesita `GROQ_API_KEY`. Si Groq no responde en 8 segundos o la respuesta no parece una versión
  limpia del texto (por ejemplo, si el modelo contestó una pregunta en vez de transcribirla), se pega
  el texto sin limpiar.
- **`cleanupModel`**: modelo de Groq para la limpieza.
- **`restoreClipboard`**: con `false` (el default), el dictado queda en el portapapeles después de
  pegarse. Con `true`, Susurro vuelve a poner lo que tenías copiado medio segundo después de pegar,
  y marca el dictado como transitorio para que los gestores de portapapeles no lo guarden. Si en
  ese medio segundo copiás otra cosa, no la pisa.

### Diccionario personal

"Editar diccionario…" en el menú abre `~/.config/susurro/diccionario.txt` (se crea con instrucciones
la primera vez). Después de guardarlo, usá "Recargar configuración".

```
# Una línea por término que querés escrito así:
Queleo
Supabase

# Lo que se transcribe mal siempre igual -> cómo va:
que leo -> Queleo
```

- **Términos**: se le pasan como pista a Whisper (local o en la nube) y a la limpieza, que los
  escribe así cuando suenan parecido. Sirve para nombres propios, marcas y palabras técnicas.
- **Reemplazos** (`oído -> escrito`): se aplican sobre la transcripción antes de la limpieza. No
  distinguen mayúsculas ni tildes y solo reemplazan palabras completas: `que leo` no toca
  "porque leo". El lado derecho también cuenta como término.

La pista empuja a Whisper hacia esas palabras, así que una palabra parecida que no esté en la lista
puede salir peor (por ejemplo "Render" como "rendering" con "Queleo" en la lista). Si pasa, agregala
también.

### Keys de API

Van en `~/.config/susurro/.env`, que no sale de tu máquina salvo hacia el proveedor correspondiente:

```
GROQ_API_KEY=gsk_...
OPENAI_API_KEY=sk-...
```

Con `transcriber: local` y `cleanup: false`, Susurro no hace ninguna llamada de red. Con `cleanup`
activado, el texto transcripto (no el audio) se manda a Groq.

## Uso

- **Mantené el atajo** mientras hablás y **soltalo** para transcribir y pegar.
- **Doble toque** para manos libres: graba sin mantener nada. Un toque más lo termina y pega. A los
  5 minutos se corta solo y transcribe lo grabado, para que una sesión olvidada no grabe toda la
  tarde.
- **Esc** cancela: descarta la grabación en curso o corta una transcripción que ya arrancó. Susurro
  solo lo observa, así que Esc le sigue llegando a la app donde estás escribiendo.
- Un toque suelto (menos de 0,3 s, sin segundo toque) se descarta.
- Con `fn`, si apretás otra tecla mientras la mantenés (por ejemplo `fn`+flecha), la grabación se
  descarta: la estabas usando como modificador.
- Mientras graba o transcribe aparece una pill flotante abajo en la pantalla: "Escuchando" al
  mantener, "Manos libres" con el tiempo transcurrido (en naranja en los últimos 30 s) y
  "Transcribiendo". Las barras rojas siguen el nivel del micrófono.
- El ícono de la barra de menú (la onda del logo) también indica el estado: normal cuando está
  listo, rojo grabando, atenuado transcribiendo y gris si está desactivado.
- **Activado** en el menú prende o apaga Susurro sin cerrarlo; mientras está apagado, el atajo
  no hace nada. El estado se recuerda entre aperturas.
- Si el cursor está justo después de una palabra o de un punto, Susurro agrega un espacio antes del
  texto, para que dos dictados seguidos no queden pegados. Para saberlo lee el carácter anterior con
  Accesibilidad; en apps que no lo exponen (muchas apps Electron y web) no agrega nada.
- El texto queda en el portapapeles después de pegarse, así que lo podés volver a pegar con ⌘V.
- **Historial** en el menú: los últimos 10 dictados, del más nuevo al más viejo. Un clic copia el
  texto completo al portapapeles, por ejemplo si se pegó en la ventana equivocada. Vive solo en
  memoria: se borra al cerrar Susurro y nunca se escribe a disco. "Borrar historial" lo vacía antes.

### Diagnóstico

- `build/Susurro.app/Contents/MacOS/Susurro --transcribe archivo.wav` corre el mismo proceso que la
  app sobre un WAV: imprime el texto crudo, el limpio y cuánto tardó cada paso.
- `build/Susurro.app/Contents/MacOS/Susurro --clean "eh bueno este nos vemos mañana"` prueba solo la
  limpieza.
