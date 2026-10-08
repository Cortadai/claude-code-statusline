# claude-code-statusline

Status lines de Claude Code en PowerShell (paleta Catppuccin Macchiato) y scripts para instalarlas y compararlas. Ver `README.md` para el uso.

## Estructura

| Ruta | Qué es | Intérprete |
|---|---|---|
| `v1-original/statusline.ps1` | Una fila, sin iconos | Windows PowerShell 5.1 |
| `v2-box/statusline.ps1` | Caja de dos filas, todo visible | **pwsh 7** |
| `v3-compact/statusline.ps1` | Una fila, iconos, avisos solo cuando hacen falta | Windows PowerShell 5.1 |
| `v2-box/CHULETA.md` | Qué significa cada elemento de la v2 | — |
| `switch.ps1` | Apunta `statusLine` de `settings.json` a una versión de este repo | — |
| `preview.ps1` | Pinta las versiones con sesiones de ejemplo | — |

## Instalar en un equipo

```powershell
git clone https://github.com/Cortadai/claude-code-statusline.git $env:USERPROFILE\repos\claude-code-statusline
cd $env:USERPROFILE\repos\claude-code-statusline
.\switch.ps1 v2      # o v1 / v3; sin argumento muestra la versión en uso
```

- `switch.ps1` apunta `settings.json` **al script dentro del repo**: no mover ni borrar el clon después.
- Hace copia `settings.json.bak-<fecha>` antes de tocar nada.
- Respeta `CLAUDE_CONFIG_DIR` si está definido.

## Cómo probar un cambio

1. `.\preview.ps1` (o `-Versions v2`) antes de dar nada por bueno: cubre sesión recién abierta, día normal, repo git con cambios, límites apretados y caché fría.
2. Los cambios se ven **en vivo** en la barra tras la siguiente respuesta de Claude Code, porque `settings.json` apunta al repo.
3. Para inspeccionar los códigos ANSI crudos, ejecutar desde **Bash** (`echo '{...}' | pwsh -NoProfile -File v2-box/statusline.ps1 | od -c`). Capturar la salida desde el host de PowerShell **elimina** los códigos de color.
4. Si se cambia la salida de una versión, regenerar el ejemplo del `README.md` con la salida real (sin códigos ANSI), no escribirlo a mano.

## Reglas (aprendidas a base de errores)

### Compatibilidad
- **v1 y v3 deben funcionar en Windows PowerShell 5.1**: los caracteres no ASCII van como code points (`[char]0x2588`, `[char]::ConvertFromUtf32(0xF06A9)`) o el archivo se guarda en UTF-8 **con BOM**. Sin eso, 5.1 lee mal `█ ░ ⚠ ↻` y los acentos.
- Leer stdin con `[Console]::In.ReadToEnd()`.
- Nada de rutas de un equipo concreto: usar `$env:USERPROFILE`, `$env:TEMP`, `$PSScriptRoot` o `CLAUDE_CONFIG_DIR`.

### Iconos
- **Solo Nerd Font Material Design (`U+F0000` en adelante)**. Los antiguos (`U+E000–F8FF`: Font Awesome, Powerline, Devicons) **no se ven en Claude Code**.
- Antes de usar un icono nuevo, comprobar que existe en la fuente (`System.Windows.Media.GlyphTypeface.CharacterToGlyphMap`).
- Todo icono debe tener alternativa de texto para `$UseIcons = $false`.

### Datos de Claude Code (JSON por stdin)
- Referencia de campos: https://code.claude.com/docs/en/statusline
- `rate_limits`, `prompt_cache` y `cost` **no llegan hasta la primera respuesta** de la sesión: nunca asumir que existen.
- Cualquier fallo debe acabar en una línea legible (bloque `catch`), nunca en salida vacía: una salida vacía deja la barra en blanco.
- Claude Code **descarta las líneas vacías**. Para separar filas hay que imprimir algo (por eso la v2 usa `$RowSeparator`).

### Ancho y alineación (v2)
- Medir el ancho visible quitando los códigos ANSI y contando con `[Globalization.StringInfo]::LengthInTextElements` (un icono de `U+F0000+` son dos `char` en .NET pero una columna).

### Privacidad
- De `~/.claude.json` solo se lee `oauthAccount` (tipo de organización, nivel de límites, nombre de la organización). No imprimir ni registrar nada más de ese archivo: contiene tokens y datos personales.
- El repo es **público**: no subir rutas, nombres de usuario, empresas ni capturas con datos reales.

### Estilo
- Código y comentarios en inglés; documentación en español.
- Ajustes del usuario como variables al principio de cada script, con un comentario de una línea. Si se añade uno, documentarlo en la tabla "Ajustes" del `README.md`.
- Colores siempre de la tabla `$colors` (Catppuccin Macchiato), nunca RGB sueltos.
