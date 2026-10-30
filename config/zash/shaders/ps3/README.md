# PS3 Edition

zfloat panel shaders for zash in the spirit of the PS3 menu (XMB). Own code, not Sony's.

One scene, `scene.glsl`, holds every element: the background, the wave band, sparkles and
light dust. The presets in `pack.toml` are that scene with values:

| preset | what it is |
|---|---|
| `ps3/wave` | the menu wave: a band of thin glowing lines, sparkles caught in it |
| `ps3/silk` | the lines merged into three broad ribbons that fold and catch the light |
| `ps3/dust` | the lines broken up into points of light drifting in depth |
| `ps3/bokeh` | the dust grown into large soft discs of light |
| `ps3/ripple` | rings of light spreading from the middle |

Two more are shaders of their own (not forms of the scene, so switching to one does not morph):

| shader | what it is |
|---|---|
| `ps3/xmb` | the menu as it looks: a deep gradient in the month's colour, soft see-through sheets of light with bright edges, faint specks (`waves`, `specks`, `glow`; `month = 0` uses your accent) |
| `ps3/coldboot` | the start-up: streaks of light rushing in to a glowing horizon |
| `ps3/tide` | a night sea of light: a grid rolling in slow swells to a bright horizon, a glow mirrored in it, stars above (`waves`, `grid`, `moon`, `stars`) |

The colour of the month (like the PS3) is an option for any of them: `month = 1`.

**Each works on its own.** Switching between them while the zfloat shows **morphs**: every
value slides to the new one, so the wave's lines break up into the dust instead of one picture
fading over the other. Elements leaving go first, elements coming arrive late; an option can
say otherwise (`morph = "early" | "late" | "even"` in pack.toml; scatter is early, so the
band breaks up before it fades).

## Using it

`~/.config/zash/zash.toml`:

```toml
[zfloat]
morph = 1.5                 # seconds a change of preset takes

[zfloat.shaders]
Claude = "ps3/wave"

[zfloat.shader_options."ps3/wave"]
speed = 0.6                 # any option, over the preset's value
```

From zeit (`~/.config/zeit/init.lua`), also later from an event, which wins over zash.toml:

```lua
z.zfloat('claude', { shader = 'ps3/wave', morph = 2 })
z.on('pane_exit', function(e) z.zfloat('claude', { shader = e.status == '0' and 'ps3/wave' or 'ps3/night' }) end)
```

or a command / key binding: `zeit zfloat-shader ps3/dust -m 2` (`none`: a plain panel).

## Writing your own

A scene is a `.glsl` file with `void mainImage(out vec4 fragColor, in vec2 fragCoord)`. It
reads `iResolution`, `iTime`, `iPhase` (time at the `speed` option's pace, smooth when it
changes), `iPanel`, `iAccent`, `iFocus`, `iOrigin` + `iScreen` (draw at `fragCoord + iOrigin`
and the panel looks over the scene like a camera), `iMonth`, and its options from pack.toml
(live values, at most 32). A picture: `channel0 = "picture.png"` under the shader's
`[shaders.NAME]` in pack.toml (beside it, or `~/…`), read with `texture(iChannel0, uv)`
(`vec2(uv.x, 1.0 - uv.y)` shows it upright; its size is `iChannelResolution0`). PNG only.

Building blocks come in with `#import "lib/band"`: from the pack's folder first, then
`~/.config/zash/shaders/`, each once. The shared library in `shaders/lib/`:
`hash` (random, noise), `month` (the month's colour, `tint`), `band` (the wave band: `width`
turns lines into silk ribbons, `scatter` into dust), `sparkles`, `dust` (four layers of depth;
`size` turns points into bokeh), `rings`.
