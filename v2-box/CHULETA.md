---
tags: [claude-code, statusline, chuleta]
creado: 2026-10-06
---

# Chuleta: status line de Claude Code

Script: `v2-box/statusline.ps1` (PowerShell 7 + Nerd Font). Se activa con `.\switch.ps1 v2` desde la raíz del repo.

## Vista general

```
Opus 5.5 · high │ ejercicio │ git:main* │ personal · Max 5x │ $1.42 · 37m · +156 −23

ctx [██░░░░░░░░] 18% 180k/1000k │ 5h [███▓▓░░░░░] 23% ↻ 2h09 │ 7d [█████▓▓▓░░] 41% ↻ sáb 03:52 │ cache 52m
```

## Línea 1: dónde estoy

| Elemento | Qué es | Color |
|---|---|---|
| `Opus 5.5` | Modelo activo | morado (mauve), fijo |
| `high` | Nivel de esfuerzo (`low`…`max`), cambia con `/effort` | lavanda, fijo |
| `ejercicio` | Carpeta del proyecto | celeste (sky), fijo |
| `git:main` | Rama actual (solo si hay `.git`) | gris + rosa (flamingo) |
| `*` | Cambios sin commit | **amarillo**, solo si los hay |
| `personal · Max 5x` | Cuenta (`personal` o el nombre de la organización Team/Enterprise) y plan, leídos de `~/.claude.json` | teal + verde, fijo |
| `$1.42` | Coste estimado a precio API. **No se cobra** con plan Max | gris claro |
| `37m` | Duración de la sesión | gris claro |
| `+156 −23` | Líneas añadidas / quitadas por Claude | verde / rojo, fijo |

## Línea 2: cuánto me queda

| Elemento | Qué es |
|---|---|
| `ctx [██░░] 18% 180k/1000k` | Contexto ocupado de la conversación |
| `⚠ /compact` | Aparece a partir del **50 %** de contexto (regla personal) |
| `5h [███▓▓░] 23% ↻ 2h09` | Límite de **5 horas** y cuánto falta para el reinicio |
| `7d [█████▓▓▓░] 41% ↻ sáb 03:52` | Límite **semanal** y cuándo se reinicia |
| `⚠` tras un límite | Al ritmo actual **llegaré al 100 % antes del reinicio** |
| `cache 52m` | Minutos que le quedan a la caché de la conversación |
| `cache ❄ fría (relee 440k)` | Caché caducada: el próximo mensaje reprocesa todo el contexto y gasta más cupo |

Los límites y la caché **no aparecen hasta la primera respuesta** de cada sesión.

## Cómo leer las barras

```
[███▓▓░░░░░]
 ███        consumido hasta ahora
    ▓▓      previsión: dónde acabaré al reiniciarse si sigo a este ritmo
      ░░░░░ libre
```

- La previsión `▓` solo sale en `5h` y `7d` (el contexto no se reinicia).
- Se suaviza al inicio de cada ventana (primeros 30 min en 5h, primer día en 7d) para que un arranque intenso no parezca alarmante.

## Qué cambia de color

**Barras y porcentajes** (`ctx`, `5h`, `7d`), según el % consumido:

| % | Color |
|---|---|
| 0–24 | 🟢 verde |
| 25–49 | 🩵 verde azulado |
| 50–74 | 🟡 amarillo |
| 75–89 | 🟠 melocotón |
| 90–100 | 🔴 rojo |

La parte `▓` sale en el mismo color, más claro.

**Avisos:**

| Aviso | Cuándo | Color |
|---|---|---|
| `⚠ /compact` | contexto ≥ 50 % | 🟠 melocotón |
| `⚠` en 5h / 7d | la previsión llega al 100 % | 🟠 melocotón |
| `cache 52m` | ≥ 5 min restantes | 🟢 verde |
| `cache 3m` | < 5 min restantes | 🟡 amarillo |
| `cache ❄ fría` | caducada | 🟡 amarillo |
| `*` en git | cambios sin commit | 🟡 amarillo |

**Fijos en gris claro:** etiquetas (`ctx`, `5h`, `7d`, `cache`), reinicios (`↻ 2h09`, `↻ sáb 03:52`), coste y duración.
**Fijos en gris oscuro:** separadores (`│`, `·`) y el prefijo `git:`.

## Iconos Nerd Font (activos desde 2026-10-07)

```
󰚩 Opus 5.5 · 󰊚 high │ 󰉋 ejercicio │ 󰘬 main* │ 󰀄 personal · Max 5x │ 󰇁 1.42 · 󰅐 37m · 󰦒 +156 −23
󰆼 [██████░░░░] 55% 550k/1000k 󰀦 /compact │ 󰔟 5h [████████▓▓] 72% 󰑐 1h40 󰀦 │ 󰃭 7d [█████▓▓▓░░] 41% 󰑐 dom 02:43 │ 󱐋 52m
```

| Icono | Sustituye a | Icono | Sustituye a |
|---|---|---|---|
| 󰚩 | modelo | 󰆼 | `ctx` |
| 󰊚 | esfuerzo | 󰔟 | (delante de `5h`) |
| 󰉋 | proyecto | 󰃭 | (delante de `7d`) |
| 󰘬 | `git:` | 󰑐 | `↻` reinicio |
| 󰀄 | plan | 󱐋 | `cache` (activa) |
| 󰇁 | `$` | 󰜗 | `cache ❄` (fría) |
| 󰅐 | duración | 󰀦 | `⚠` avisos |
| 󰦒 | líneas +/− | | |

- Solo se usan iconos **Material Design** (`U+F0000`+). Los antiguos de Font Awesome/Powerline (`U+E000–F8FF`, p. ej. la carpeta `U+F07B`) **no se ven en Claude Code**.
- La fuente es CaskaydiaCove Nerd Font; si se cambia por una sin Nerd Font, los iconos salen como `□`.

## Ajustes rápidos (al principio del script)

| Variable | Valor | Para qué |
|---|---|---|
| `$CompactThreshold` | `50` | % de contexto a partir del cual sale `⚠ /compact` |
| `$UseBox` | `$true` | Caja con bordes redondeados alrededor de las dos líneas (`$false` = sin caja). Ocupa 2 filas más y se rompe si la terminal es más estrecha que la caja |
| `$RainbowBox` | `$true` | Borde de la caja en degradado con los acentos de la paleta (rojo → melocotón → amarillo → verde → teal → sky → sapphire → azul → lavanda → mauve → rosa). `$false` = gris |
| `$RainbowDim` | `0.7` | Cuánto se apaga el arcoíris mezclándolo con el fondo: `0` = colores vivos, `0.7` = muy tenue, `1` = invisible |
| `$RowSeparator` | `"dotted"` | Separación entre las dos filas dentro de la caja: `"dotted"` (punteada gris `├┄┄┤`), `"line"` (línea con el degradado `├──┤`), `"blank"` (fila vacía) o `"none"` |
| `$UseIcons` | `$true` | `$false` vuelve a las etiquetas de texto (`ctx`, `git:`, `↻`, `cache`, `$`) |
