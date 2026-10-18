# Pitch film (trailer) sounds

Sounds of the pitch film (`export/video/pitch.mp4`, 59.95 s: the approved intro from its 2.0 s, then the film body). Cue list:
`docs/audio.md`, section "Pitch film". Not used by the game. The new files in this folder are Freesound previews (CC0,
page checked), trimmed with ffmpeg, Ogg Vorbis 44.1 kHz q5, not normalised. Credits: `assets/CREDITS.md`.

The mix is code, not a DAW session: every cue below is a row of the `SFX`, `STEMS` and `MUSIC` tables in
`tools/video/film.html`, tied to the picture timeline (`TL`), so a retimed shot takes its sounds with it.
`python3 tools/video/mix.py` measures each placed sound and sets it to its planned loudness, then masters the whole
film to -14 LUFS integrated with a -2.5 dBTP limiter (see `tools/video/README.md`).

Columns: Film time = final-film seconds (6.0 s of intro + film). Trim = the part of the file used. Level = loudness of the
placed sound before the master (LUFS, or sample peak in dBFS for very short sounds); `cap` = its own peak limit. The
master then lifts the whole mix by about +7 dB.

## New files (this folder)

| T# | File | Film time (s) | Trim | Level |
|---|---|---|---|---|
| T1 | `t1_rain_loop.ogg` | 0 to 5.75 | 8 s seamless loop from its 2.0 s (the cut intro), fades 0.3 / 0.5 s | -26 LUFS |
| T2, T6 | `t2_far_thunder.ogg` (mono) | 0.4, 3.5 | whole file (source seconds 5 to 10), fade-out 0.5 s | -28, -29 LUFS |
| T3 (1st) | `t3a_thunderclap.ogg` | 0.8 | first 3.0 s, fade-out 1.0 s | -24 LUFS, cap -7 dBFS |
| T3 (2nd) | `t3b_close_strike.ogg` | 1.4 | first 3.0 s (starts on the strike), fade-out 1.2 s | -22 LUFS, cap -6 |
| T4 | `t4_final_strike.ogg` | 1.9 | first 3.8 s, fade-out 1.5 s. The plain file, raised in the mix (Burcu's call) | -22 LUFS, cap -6 |
| T7 | `t7_noise_riser.ogg` | 4.05 to 5.65 | whole file (1.6 s), fades 0.08 / 0.05 s | -27 LUFS, cap -8 |
| T9, T21 | `t9_heartbeat.ogg` | 6.07, 7.17; 37.01 | whole file (one lub-dub, 0.8 s). The lub peaks 0.15 s in, on the red glow at 6.22, 7.32, 37.16; the dub 0.45 s later | -20, -22 LUFS |
| T11 and the hits | `t11_low_impact.ogg` | see the cue list | first 1.6 to 4.0 s with a long fade-out: statement stings, title card booms, the wave, the logo | -19 to -27 LUFS, cap -6 to -10 |
| T27 | `t27_egg_crack.ogg` | 46.29 | whole file (2.7 s) at normal speed: its small cracks (0.34, 0.58 s into the file) and the big one (1.08 s) set the sped-up picture's cracks (46.63, 46.87) and the burst (47.37) | -21 LUFS, cap -8 |
| T31 | `t31_tv_off.ogg` | 58.75 | whole file (0.28 s), on the CRT power-off at the end | peak -9 dBFS |

`t4_final_strike_layered.ogg` stays as the T4 alternative; it is not in the mix.

## Game files used by the film (no copies)

| T# | File | Film time (s) | Trim | Level |
|---|---|---|---|---|
| T5 | `globe/keyboard_typing_loop.ogg` (G3) | 2.45 to 3.3 | first 0.85 s | -27 LUFS |
| T11b, T23b, T25c, T25d, T28b, T29b, T32b, T32c | `globe/keyboard_typing_loop.ogg` (G3) | 7.8, 38.0, 41.3, 42.4, 47.45, 50.25, 55.4, 55.9 | as long as each line types (0.5 to 1.75 s) | -27 to -29 LUFS |
| T12 | `diorama/winter_wind.ogg` (D1) | 10.2 to 14.2 | from 4 s, 4.0 s, fades 0.6 / 0.3 s | -25 LUFS |
| T13, T16, T19, T24, T30 (glitch layer) | `globe/glitch_corruption.ogg` (G7) | 11.9, 21.5, 27.7, 39.45, 53.15 | first 0.45 s, under the card boom (T11) | -27 LUFS |
| T14 (glitch cuts) | `globe/glitch_corruption.ogg` (G7) | 14.1, 29.5, 41.0, 44.2 | first 0.45 s | -23 to -24 LUFS |
| T15 | `globe/whoosh.ogg` (G5) | 18.8 (peaks on the cut at 20.9) | whole file | -24 LUFS |
| T17 | `globe/target_lock_trim.ogg` (G4) | 25.24 | whole file | -26 LUFS |
| T25 | `globe/spaceship_ambience.ogg` (G2) | 41.0 to 44.2 | first 3.2 s | -28 LUFS |
| T25e | `menu/ui_hover.ogg` (M2) | 42.85 | whole file, when the digit 3 settles | peak -17 dBFS |
| T26 | `globe/glitch_corruption.ogg` (G7) | 46.0 | 0.6 to 1.35 s | -23 LUFS |
| T29 | `globe/guitar_swell_trim.ogg` (R1) | 49.3 | whole file: the calm "AAA GAME" label, no hit | -22 LUFS |
| T32 | `menu/ui_hover.ogg` (M2) | 55.7, 56.02, 56.34, 56.66 | whole file, one per portrait | peak -18 dBFS |
| T33 (music bed) | `menu/title.ogg` (M1) | 6.0 to 59.45 | from 129.8 s, so its own swells peak on Fener's lamp (15.3) and on the logo (51.25); volume curve in `MUSIC.keys` | -24 LUFS |

## Game sound recorded with the clips (stems)

`tools/video/capture.sh` records the game's own sound with every clip (Godot Movie Maker, Music bus muted):
`export/video/clips/<clip>/clip.wav`. The mix cuts it like the picture (same in-point and speed).

| T# | Clip | Film time (s) | What is heard | Level |
|---|---|---|---|---|
| T14b | `fener_mini` | 14.1 to 20.9 | wind (FN1), footsteps (FN2), the mother's whistle (FN5), lamp click (FN3), found (FN6) | -21 LUFS, cap -12 |
| T15b | `globe_full` | 20.9 to 24.7 | at 1.1x: swell (G1), drone (G9) | -28 LUFS |
| T17b | `globe_full` | 24.7 to 27.7 | the same take at 1.1x: drone, coordinates typing (G3), zoom whoosh (G5) | -26 LUFS |
| T20 | `io_mini` | 29.5 to 32.0 | at 2.9x: the pipes lock (C10), the sea draws back | -22 LUFS |
| T20a | `io_mini` | 32.0 to 37.1 | at 1.25x: wave rising (C3), the wave hits (C4), water; hard cut to silence | -20 LUFS |
| T22 | `menu_roles` | 37.7 to 41.0 | hover (M2) on Devlet, then on Vatandaş | -27 LUFS, cap -14 |
| T25b | `globe_spin2` | 41.0 to 44.2 | at 1.1x: drone (G9) | -28 LUFS |
| T25f | `fire_mini` | 44.2 to 45.2 | at 1.15x: fire and wind (FR1), the fence cut (FR5, FR5.2, FR6) | -22 LUFS, cap -10 |
| T25g | `fire_mini` | 45.2 to 46.4 | at 1.15x: fire and wind (FR1), the kangaroos run (FR11) | -22 LUFS, cap -10 |

The diorama clip's sound is not used (it carries the hidden intro card's typing); T12 (D1) plays there instead.

## Notes

- T10 (the voice "Sesimi duyan var mı?"): no recording, dropped by Burcu. The on-screen echo rings stay.
- Silence: T8 (5.75 to 6.0, black), the hard cut to black (37.1 to 37.7, only the T21 heartbeat) and the end after
  the CRT power-off (59.45 to 59.95).
