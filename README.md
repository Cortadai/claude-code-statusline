# claude-statusline

Tres status lines para [Claude Code](https://code.claude.com) en PowerShell, con la paleta Catppuccin Macchiato, y un script para cambiar entre ellas.

## Versiones

### v1 · original
Una fila, sin iconos. Funciona con Windows PowerShell 5.1.
```
Opus 5.5 (1M context) | [█░░░░░░░░░] 18% | 180k/1000k | git:main* | mods | entelgy - team 5x
```

### v2 · caja
Dos filas dentro de una caja con borde arcoíris, con todo visible siempre: límites 5h/7d con barra de previsión, caché, coste, duración y líneas cambiadas. Necesita **PowerShell 7** y una **Nerd Font**. Detalle de cada elemento en [`v2-box/CHULETA.md`](v2-box/CHULETA.md).
```
╭──────────────────────────────────────────────────────────────────────────────────────────────╮
│ 󰚩 Opus 5.5 · 󰊚 high │ 󰉋 mods │ 󰀄 entelgy · team 5x │ 󰇁 1.42 · 󰅐 37m · 󰦒 +156 −23              │
├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┤
│ 󰆼 [██░░░░░░░░] 18% 180k/1000k │ 󰔟 5h [███▓▓░░░░░] 23% 󰑐 2h08 │ 󰃭 7d [█████▓▓▓▓░] 41% 󰑐 dom 21:45 │ 󱐋 52m │
╰──────────────────────────────────────────────────────────────────────────────────────────────╯
```

### v3 · compacta
La v1 con iconos y los límites de la v2, pero tranquila: una fila, y los avisos solo aparecen cuando hacen falta. Funciona con Windows PowerShell 5.1; necesita una **Nerd Font** (o `$UseIcons = $false`).
```
Normal:    󰚩 Opus 5.5 · 󰊚 high | 󰆼 [█░░░░░░░░░] 18% | 180k/1000k | 󰉋 mods | 󰀄 entelgy - team 5x | 󰔟 5h 23%
Apretado:  … | 550k/1000k 󰀦 | … | 󰔟 5h 82% 󰀦 󰑐 1h39 | 󰃭 7d 61%
Café:      … | 󰔟 5h 30% | 󰃭 7d 52% | 󰜗 fría (relee 380k)
```

| Elemento | Cuándo aparece |
|---|---|
| `󰆼 [█░░] 18% \| 180k/1000k` | Siempre. Contexto ocupado; `󰀦` desde el 50 % (hora de compactar) |
| `󰔟 5h 23%` | Siempre, tras la primera respuesta. Límite de 5 horas |
| `󰃭 7d 61%` | Desde el 50 %. Límite semanal |
| `󰀦 󰑐 1h39` junto a 5h/7d | Si al ritmo actual llegas al 100 % antes del reinicio |
| `󰜗 fría (relee 380k)` | La caché caducó: el próximo mensaje reprocesa todo el contexto |

Colores de barras y porcentajes: verde < 25 % · teal < 50 % · amarillo < 75 % · melocotón < 90 % · rojo.

## Uso

```powershell
.\switch.ps1          # versión en uso y disponibles
.\switch.ps1 v3       # cambia a v3 (guarda copia de settings.json)
.\preview.ps1         # pinta las tres con sesiones de ejemplo
.\preview.ps1 -Versions v1,v3
```

`switch.ps1` apunta el `statusLine` de `~/.claude/settings.json` al script de este repo, así que las ediciones se aplican sin reinstalar. El cambio se ve tras la siguiente respuesta de Claude Code. Para deshacerlo, restaura el `settings.json.bak-…` que deja junto al original.

## Requisitos

- **Windows PowerShell 5.1** (v1, v3) o **PowerShell 7** (v2): `winget install Microsoft.PowerShell`.
- **Nerd Font** para los iconos (v2, v3), por ejemplo CaskaydiaCove: `scoop bucket add nerd-fonts; scoop install CascadiaCode-NF` o desde [nerdfonts.com](https://www.nerdfonts.com). Selecciónala en Windows Terminal → Configuración → Valores predeterminados → Apariencia → Tipo de fuente.
  - **`Nerd Font Mono`**: los iconos caben en una celda (más pequeños, alineados).
  - **`Nerd Font`**: iconos a tamaño completo, invaden un poco la celda siguiente.
  - Solo se usan iconos Material Design (`U+F0000`+); los antiguos (`U+E000–F8FF`) no se ven en Claude Code.
- Opcional: tema **Catppuccin Macchiato** en Windows Terminal (el degradado de la caja de la v2 se funde con ese fondo).

## Ajustes

Al principio de cada script:

| Variable | v2 | v3 | Para qué |
|---|---|---|---|
| `$CompactThreshold` | 50 | 50 | % de contexto desde el que sale el aviso de compactar |
| `$WeekThreshold` | | 50 | % desde el que se muestra el 7d |
| `$UseIcons` | ✓ | ✓ | `$false` = etiquetas de texto en lugar de iconos |
| `$UseBox`, `$RainbowBox`, `$RainbowDim`, `$RowSeparator` | ✓ | | Caja, degradado, atenuado y separador entre filas |
