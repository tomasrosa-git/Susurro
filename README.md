# Susurro

Dictado por voz para todo macOS. Mantené apretada una tecla, hablá, soltá: el texto aparece donde
esté el cursor, en cualquier app. Corre en la barra de menú, transcribe localmente con
[whisper.cpp](https://github.com/ggml-org/whisper.cpp) y funciona sin conexión. Sin cuentas ni
telemetría.

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

## Compilar y ejecutar

```bash
scripts/build-app.sh
open build/Susurro.app
```

Para correr los tests: `scripts/test.sh`.

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
3. Compilá con `SUSURRO_SIGN_IDENTITY="Susurro Dev" scripts/build-app.sh`.

## Configuración

`~/.config/susurro/config.json` (se crea con los defaults al primer arranque; el menú tiene
"Abrir configuración…" y "Recargar configuración"):

```json
{
  "hotkey" : "fn",
  "language" : "auto",
  "whisperCLI" : "/opt/homebrew/bin/whisper-cli",
  "whisperModel" : "small"
}
```

- **`hotkey`**: `fn`, o una combinación como `ctrl+option+space`, `cmd+shift+d` o `f13`. Modificadores:
  `ctrl`, `option`/`alt`, `shift`, `cmd`. Teclas: letras, números, `space`, `return`, `tab`,
  `delete`, `f1`–`f19`. Salvo `f13`–`f19`, una combinación necesita al menos un modificador. La
  combinación queda reservada para Susurro: no le llega a la app activa.
- **`language`**: `auto` para detectar el idioma, o un código como `es` o `en`. Fijarlo mejora la
  precisión en frases cortas.
- **`whisperModel`**: `small`, `medium` (busca `ggml-<nombre>.bin` en
  `~/Library/Application Support/Susurro/models/`) o una ruta absoluta a cualquier modelo ggml.
- **`whisperCLI`**: ruta a `whisper-cli`.

## Uso

- **Mantené el atajo** mientras hablás y **soltalo** para transcribir y pegar.
- Un toque corto (menos de 0,3 s) se ignora.
- Con `fn`, si apretás otra tecla mientras la mantenés (por ejemplo `fn`+flecha), la grabación se
  descarta: la estabas usando como modificador.
- El ícono de la barra de menú indica el estado: 🎙 listo, rojo grabando, onda transcribiendo.
- El texto queda en el portapapeles después de pegarse, así que lo podés volver a pegar con ⌘V.

### Diagnóstico

`build/Susurro.app/Contents/MacOS/Susurro --transcribe archivo.wav` transcribe un WAV con la misma
configuración que la app e imprime el texto y el tiempo que tardó.
