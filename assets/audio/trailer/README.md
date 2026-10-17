# Pitch film (trailer) sounds

Sounds of the pitch film (`export/video/pitch.mp4`, 58.4 s: the approved 8.0 s intro, then the film body). Cue list:
`docs/audio.md`, section "Pitch film". Not used by the game. The new files in this folder are Freesound previews (CC0,
page checked), trimmed with ffmpeg, Ogg Vorbis 44.1 kHz q5, not normalised. Credits: `assets/CREDITS.md`.

The mix is code, not a DAW session: every cue below is a row of the `SFX`, `STEMS` and `MUSIC` tables in
`tools/video/film.html`, tied to the picture timeline (`TL`), so a retimed shot takes its sounds with it.
`python3 tools/video/mix.py` measures each placed sound and sets it to its planned loudness, then masters the whole
film to -14 LUFS integrated with a -2.5 dBTP limiter (see `tools/video/README.md`).

Columns: Film time = final-film seconds (intro + film). Trim = the part of the file used. Level = loudness of the
placed sound before the master (LUFS, or sample peak in dBFS for very short sounds); `cap` = its own peak limit. The
master then lifts the whole mix by about +7 dB.

## New files (this folder)

| T# | File | Film time (s) | Trim | Level |
|---|---|---|---|---|
| T1 | `t1_rain_loop.ogg` | 0 to 7.75 | 8 s seamless loop, fades 0.4 / 0.5 s | -26 LUFS |
| T2, T6 | `t2_far_thunder.ogg` (mono) | 2.4, 5.5 | whole file (source seconds 5 to 10), fade-out 0.5 s | -28, -29 LUFS |
| T3 (1st) | `t3a_thunderclap.ogg` | 2.8 | first 3.0 s, fade-out 1.0 s | -24 LUFS, cap -7 dBFS |
| T3 (2nd) | `t3b_close_strike.ogg` | 3.4 | first 3.0 s (starts on the strike), fade-out 1.2 s | -22 LUFS, cap -6 |
| T4 | `t4_final_strike.ogg` | 3.9 | first 3.8 s, fade-out 1.5 s. The plain file, raised in the mix (Burcu's call) | -22 LUFS, cap -6 |
| T7 | `t7_noise_riser.ogg` | 6.05 to 7.65 | whole file (1.6 s), fades 0.08 / 0.05 s | -27 LUFS, cap -8 |
| T9, T21 | `t9_heartbeat.ogg` | 8.07, 9.17; 34.31 | whole file (one lub-dub, 0.8 s). The lub peaks 0.15 s in, on the red glow at 8.22, 9.32, 34.46; the dub 0.45 s later | -20, -22 LUFS |
| T11 and the hits | `t11_low_impact.ogg` | see the cue list | first 1.6 to 4.0 s with a long fade-out: statement stings, title card booms, the wave, the logo | -19 to -27 LUFS, cap -6 to -10 |
| T27 | `t27_egg_crack.ogg` | 43.22 | whole file (2.7 s): its small cracks fall on the egg's cracks (43.45, 43.9), the big one on the burst (44.3) | -21 LUFS, cap -8 |
| T31 | `t31_tv_off.ogg` | 52.25 | whole file (0.28 s), on the CRT power-off | peak -9 dBFS |

`t4_final_strike_layered.ogg` stays as the T4 alternative; it is not in the mix.

## Game files used by the film (no copies)

| T# | File | Film time (s) | Trim | Level |
|---|---|---|---|---|
| T5 | `globe/keyboard_typing_loop.ogg` (G3) | 4.45 to 5.3 | first 0.85 s | -27 LUFS |
| T11b, T23b, T25c, T25d, T28b, T29b, T32b, T32c | `globe/keyboard_typing_loop.ogg` (G3) | 9.8, 35.25, 39.7, 40.9, 44.4, 47.55, 53.45, 53.95 | as long as each line types (0.5 to 1.75 s) | -27 to -29 LUFS |
| T12 | `diorama/winter_wind.ogg` (D1) | 12.2 to 16.3 | from 4 s, 4.0 s, fades 0.6 / 0.3 s | -25 LUFS |
| T13, T16, T19, T24, T30 (glitch layer) | `globe/glitch_corruption.ogg` (G7) | 13.9, 21.3, 27.2, 37.3, 50.6 | first 0.45 s, under the card boom (T11) | -27 LUFS |
| T14 (glitch cuts) | `globe/glitch_corruption.ogg` (G7) | 16.1, 29.0, 36.9, 39.4 | first 0.45 s | -23 to -25 LUFS |
| T15 | `globe/whoosh.ogg` (G5) | 18.6 (peaks on the cut at 20.7) | whole file | -24 LUFS |
| T17 | `globe/target_lock_trim.ogg` (G4) | 25.65 | whole file | -26 LUFS |
| T25 | `globe/spaceship_ambience.ogg` (G2) | 39.4 to 42.9 | first 3.5 s | -28 LUFS |
| T25e | `menu/ui_hover.ogg` (M2) | 41.35 | whole file, when the digit 3 settles | peak -17 dBFS |
| T26 | `globe/glitch_corruption.ogg` (G7) | 42.5 | 0.6 to 1.35 s | -23 LUFS |
| T29 | `globe/guitar_swell_trim.ogg` (R1) | 46.2 | whole file: the calm "AAA" label, no hit | -22 LUFS |
| T32 | `menu/ui_hover.ogg` (M2) | 53.75, 54.07, 54.39, 54.71 | whole file, one per portrait | peak -18 dBFS |
| T33 (music bed) | `menu/title.ogg` (M1) | 8.0 to 57.8 | from 134.35 s, so its own swells peak on the diorama (12.75) and on the logo (48.75); volume curve in `MUSIC.keys` | -24 LUFS |

## Game sound recorded with the clips (stems)

`tools/video/capture.sh` records the game's own sound with every clip (Godot Movie Maker, Music bus muted):
`export/video/clips/<clip>/clip.wav`. The mix cuts it like the picture (same in-point and speed).

| T# | Clip | Film time (s) | What is heard | Level |
|---|---|---|---|---|
| T14b | `fener_mini` | 16.1 to 20.7 | wind (FN1), footsteps (FN2), the mother's whistle (FN5), lamp click (FN3), found (FN6) | -21 LUFS, cap -12 |
| T15b | `globe_spin` | 20.7 to 23.6 | swell (G1), drone (G9) | -28 LUFS |
| T17b | `globe_lock_io` | 23.6 to 27.2 | at 1.5x: drone, coordinates typing (G3), zoom whoosh (G5) | -24 LUFS |
| T20 | `io_mini` | 29.0 to 34.4 | wave rising (C3), the wave hits (C4), water; hard cut to silence | -20 LUFS |
| T22b | `title` | 35.0 to 36.9 | title screen ambience | -34 LUFS, cap -24 |
| T22 | `menu_roles` | 36.9 to 39.4 | hover (M2) on Devlet | -27 LUFS, cap -14 |
| T25b | `globe_spin2` | 39.4 to 42.9 | drone (G9) | -28 LUFS |

The diorama clip's sound is not used (it carries the hidden intro card's typing); T12 (D1) plays there instead.

## Notes

- T10 (the voice "Sesimi duyan var mı?"): no recording, dropped by Burcu. The on-screen echo rings stay.
- Silence: T8 (7.75 to 8.0, black), the hard cut to black (34.4 to 35.0, only the T21 heartbeat), the gap after the
  CRT power-off (52.9 to 53.3) and the end (57.8 to 58.4).
