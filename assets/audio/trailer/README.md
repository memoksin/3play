# Pitch film (trailer) sounds

For mixing the ~50 s pitch film. Cue list and picks: `docs/audio.md`, section "Pitch film". Not used by the game. All new files are Freesound previews (CC0, page checked), trimmed with ffmpeg, Ogg Vorbis 44.1 kHz q5, not normalised. Levels are the raw level of each file (integrated LUFS / sample peak), set them by ear in the mix. Credits: `assets/CREDITS.md`.

## New files (this folder)

| T# | File | Film time (s) | Trim / notes | LUFS / peak |
|---|---|---|---|---|
| T1 | `t1_rain_loop.ogg` | 0 to 8 | Rain.wav (idomusics), source 20 to 29 s, +12 dB (source is very quiet, -39.6 LUFS), 8 s seamless loop (1 s crossfade). Loop it under the whole intro. | -27.8 / -9.9 dBFS |
| T2, T6 | `t2_far_thunder.ogg` (mono) | 2.4, 5.5 | Source seconds 5 to 10, short fades. Same file for both. | -24.2 / -5.7 dBFS |
| T3 (1st) | `t3a_thunderclap.ogg` | 2.8 | Thunderclap (Fission9), 0.5 to 10.9 s, tail fade. | -26.1 / -0.2 dBFS |
| T3 (2nd) | `t3b_close_strike.ogg` | 3.4 | Very close lightning strike (Simon Spiers). Source is 4 s of quiet, then the strike at 20 s; file starts on the strike (19.9 to 27 s). | -11.7 / +0.4 dBFS |
| T4 | `t4_final_strike.ogg` | 3.9 | Thunder with no rain (shazzakip), 15 to 24 s (loudest rumble). Clearly weak (about 18 LU below T3b). | -30.2 / -11.8 dBFS |
| T4 (alt) | `t4_final_strike_layered.ogg` | 3.9 | T4 (+6 dB) mixed with T3b, limiter, 7 s. Use instead of T4 if T4 is too small. | -15.1 / +0.8 dBFS |
| T7 | `t7_noise_riser.ogg` | 6.05 to 7.65 | Riser, the last 1.6 s before the source goes silent (source 3.0 to 4.6 s), 80 ms fade-in, -1.5 dB. Fits the slot. | -15.9 / -1.0 dBFS |
| T9, T21 | `t9_heartbeat.ogg` | 8.2, 8.5, 9.2, 9.5; 31.12, 31.40 | One lub-dub (source 2.45 to 3.25 s), 0.8 s. T21 reuses it. | -22.9 / -9.4 dBFS |
| T11 | `t11_low_impact.ogg` | 10.0 | Cinematic Low Pitch Impact (Jofae), 6.15 s with tail fade. Also the statement sting (T23, T28) and the base of the title-card hit (T13, T16, T19, T24, T30). | -16.5 / +0.4 dBFS |
| T27 | `t27_egg_crack.ogg` | 41.5 | Egg cracking (FngerSounds), 2.7 s. Source clipped (+1.5 dBFS), lowered 3 dB. | -15.7 / -1.1 dBFS |
| T31 | `t31_tv_off.ogg` | 49.1 | Turning the TV off (Cloud-10), 0.28 s. Very short and quiet (LUFS not measurable, gated), raise it. | n/a / -12.2 dBFS |

## Reused game files (no copies)

| T# | Existing file | Film time (s) |
|---|---|---|
| T5, T29 (typing) | `assets/audio/globe/keyboard_typing_loop.ogg` (G3) | 4.45 to 5.3; 44.4 to 45.9 |
| T29 (card swell) | `assets/audio/globe/guitar_swell_trim.ogg` (R1) | 43.8 |
| T15 | `assets/audio/globe/whoosh.ogg` (G5) | 19.2 |
| T17 | `assets/audio/globe/target_lock_trim.ogg` (G4) | 24.55 |
| T20 | `assets/audio/connect/pipe_water_stream.ogg` (C5), `assets/audio/connect/water_echo.ogg` (C6) | 28 to 31 |
| T22 | `assets/audio/menu/title.ogg` (M1), `assets/audio/menu/ui_hover.ogg` (M2) | 31.7 |
| T25 | `assets/audio/globe/spaceship_ambience.ogg` (G2) | 36.3 to 40 |
| T12 (after the rip) | `assets/audio/diorama/winter_wind.ogg` (D1) | 12.4 |
| T13, T16, T19, T24, T30 (title cards) | `assets/audio/trailer/t11_low_impact.ogg` (T11) | 14.3, 20.2, 26.1, 34.3, 47.4 |
| T23, T28 (statements) | `assets/audio/trailer/t11_low_impact.ogg` (T11) | 32.25, 41.6 |
| T14, T26 (glitch cuts, pixelate) | `assets/audio/globe/glitch_corruption.ogg` (G7) | 16.6, 28.0, 36.3, 43.8; 39.7 |
| T18 (flash whoosh) | `assets/audio/globe/whoosh.ogg` (G5) | 25.75 |
| T33 (music bed, quiet) | `assets/audio/menu/title.ogg` (M1) | whole film |

## Still open

- T4: Burcu decides between `t4_final_strike.ogg` and `t4_final_strike_layered.ogg`.
- T12: Burcu's note lists only the D1 wind; no separate rip sound.
