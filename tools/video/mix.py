#!/usr/bin/env python3
"""Pitch film sound mix: export/video/film_audio.json -> export/video/pitch_audio.wav (+ pitch.mp4 with --mux).

film_audio.json is written by `node tools/video/render.mjs film` (also by a --still run) from the MUSIC, STEMS and SFX
tables in tools/video/film.html, with every time in final-film seconds (intro + film). Each sound is cut from its file
(ss / dur / loop / tempo / fades), measured with ffmpeg's EBU R128 meter and set to its planned loudness (`lu`, LUFS) or
sample peak (`peak`, dBFS, for sounds too short to measure); `ceil` (dBFS, optional) caps a layer's peaks after that
gain, for stems with sharp in-game clicks. Stems are the game's own sound captured with each clip
(export/video/clips/<clip>/clip.wav, see capture.sh), cut to the clip's in-point and speed. The music bed follows the
`keys` volume curve (dB). The sum is mastered to -14 LUFS integrated with a -2.5 dBTP limiter, so nothing clips (also after AAC).

  python3 tools/video/mix.py                    # -> export/video/pitch_audio.wav and a loudness report
  python3 tools/video/mix.py --mux              # + export/video/pitch.mp4 (pitch_film.mp4 picture copied, AAC 256 kb/s)
  python3 tools/video/mix.py --mux --video other.mp4 --out other_with_sound.mp4
  python3 tools/video/mix.py --mux --web        # + export/video/pitch_web.mp4: same picture and sound, ~45 MB for the web
"""
import json, os, re, subprocess, sys, tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
VID = os.path.join(ROOT, "export", "video")
PARTS = os.path.join(VID, "mix")
SR = 48000
TARGET_LUFS = -14.0
LIMIT_DBTP = -2.5  # leaves room for the AAC encoder overshoot (-1 dBTP or lower in the mp4)
WEB_KBPS = 5800    # web export video bitrate (2-pass x264): ~45 MB for the 59 s film with 192 kb/s AAC


def run(args, **kw):
    r = subprocess.run(args, capture_output=True, text=True, **kw)
    if r.returncode != 0:
        sys.exit(f"ffmpeg failed: {' '.join(args)}\n{r.stderr[-2000:]}")
    return r


def loudness(path, true_peak=False):
    """(integrated LUFS, peak dB) of a file; peak is true peak with true_peak, else sample peak."""
    r = run(["ffmpeg", "-nostats", "-i", path, "-af", f"ebur128=peak={'true' if true_peak else 'sample'}", "-f", "null", "-"])
    tail = r.stderr[r.stderr.rfind("Summary:"):]
    i = float(re.search(r"I:\s+(-?[\d.]+) LUFS", tail).group(1))
    p = float(re.search(r"Peak:\s+(-?[\d.inf]+) dBFS", tail).group(1)) if "Peak:" in tail else -99.0
    lra = re.search(r"LRA:\s+(-?[\d.]+) LU", tail)
    return i, p, float(lra.group(1)) if lra else 0.0


def cut(name, src, ss=0.0, dur=None, loop=False, fade=(0, 0), tempo=1.0):
    """Cuts one sound to export/video/mix/<name>.wav (48 kHz stereo float): trim, loop, tempo, fades."""
    out = os.path.join(PARTS, name + ".wav")
    args = ["ffmpeg", "-v", "error", "-y"]
    if loop:
        args += ["-stream_loop", "-1"]
    if ss:
        args += ["-ss", f"{ss:.4f}"]
    args += ["-i", src]
    fl = [f"aresample={SR}", "aformat=sample_fmts=fltp:channel_layouts=stereo"]
    if tempo != 1.0:
        fl.append(f"atempo={tempo:.4f}")
    length = None
    if dur is not None:
        length = dur
        fl.append(f"atrim=0:{dur:.4f}")
    else:
        length = float(run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", src]).stdout) - ss
    fi, fo = fade
    if fi > 0:
        fl.append(f"afade=t=in:st=0:d={fi:.3f}")
    if fo > 0:
        fl.append(f"afade=t=out:st={max(0.0, length - fo):.3f}:d={fo:.3f}")
    run(args + ["-af", ",".join(fl), "-c:a", "pcm_f32le", out])
    return out


def gain_for(path, lu=None, peak=None, label=""):
    i, p, _ = loudness(path)
    if lu is not None and i > -69:
        return lu - i, f"{i:6.1f} LUFS -> {lu}"
    if lu is not None:  # too short for the gated meter: fall back to a peak target 10 dB over the loudness target
        peak = lu + 10
        print(f"  note: {label} too short to measure, set by peak {peak} dBFS")
    return peak - p, f"peak {p:6.1f} dBFS -> {peak}"


def ceil(item):
    """peak cap of one layer (alimiter at `ceil` dBFS, 4x oversampled), or no filter."""
    if "ceil" not in item:
        return ""
    return f"aresample={SR * 4},alimiter=limit={10 ** (item['ceil'] / 20):.4f}:attack=1:release=40:level=disabled,aresample={SR}"


def curve(keys, offset):
    """volume expression (linear) for a piecewise linear dB curve; t is local to the part, keys are final seconds."""
    pts = [(t - offset, db) for t, db in keys]
    expr = f"{pts[-1][1]}"
    for (t0, d0), (t1, d1) in reversed(list(zip(pts, pts[1:]))):
        seg = f"({d0}+({d1}-({d0}))*(t-{t0:.4f})/{max(t1 - t0, 1e-4):.4f})"
        expr = f"if(lt(t,{t1:.4f}),{seg},{expr})"
    expr = f"if(lt(t,{pts[0][0]:.4f}),{pts[0][1]},{expr})"
    return f"pow(10,({expr})/20)"


def main():
    argv = sys.argv[1:]
    plan = json.load(open(os.path.join(VID, "film_audio.json")))
    os.makedirs(PARTS, exist_ok=True)
    length = plan["length"]
    layers = []  # (wav, at, gain dB, extra filter, label)
    m = plan["music"]
    mdur = length - m["start"]
    wav = cut("music", os.path.join(ROOT, m["file"]), ss=m["from"], dur=mdur)
    g, how = gain_for(wav, lu=m["lu"], label="music")
    layers.append((wav, m["start"], g, f"volume='{curve(m['keys'], m['start'])}':eval=frame", "music bed"))
    print(f"music  {m['file']} from {m['from']} s: {how}")
    for k, s in enumerate(plan["stems"]):
        src = os.path.join(VID, "clips", s["clip"], "clip.wav")
        if not os.path.exists(src):
            print(f"  skip stem {s['clip']}: no clip.wav")
            continue
        wav = cut(f"stem{k:02d}_{s['clip']}", src, ss=s["in"], dur=s["len"] * s["speed"], tempo=s["speed"], fade=tuple(s["fade"]))
        g, how = gain_for(wav, lu=s["lu"], label=s["clip"])
        layers.append((wav, s["at"], g, ceil(s), f"{s['T']} stem {s['clip']}"))
        print(f"{s['T']:6} {s['at']:6.2f}  stem {s['clip']}: {how}")
    for k, c in enumerate(plan["sfx"]):
        src = os.path.join(ROOT, c["file"])
        at = c["at"]
        ss = c.get("ss", 0.0)
        if at < 0:  # starts before the film: drop the part before 0
            ss -= at
            at = 0.0
        wav = cut(f"sfx{k:02d}_{c['T']}", src, ss=ss, dur=c.get("dur"), loop=c.get("loop", False), fade=tuple(c.get("fade", (0, 0))))
        g, how = gain_for(wav, lu=c.get("lu"), peak=c.get("peak"), label=c["T"])
        layers.append((wav, at, g, ceil(c), f"{c['T']} {c['note']}"))
        print(f"{c['T']:6} {at:6.2f}  {os.path.basename(c['file'])}: {how}")

    # sum: every layer at its time, then pad / trim to the film length
    def mixdown(sel, path):
        args = ["ffmpeg", "-v", "error", "-y"]
        fl = []
        for n, (wav, at, g, extra, _) in enumerate(sel):
            args += ["-i", wav]
            chain = [f"volume={g:.2f}dB"] + ([extra] if extra else []) + [f"adelay=delays={round(at * 1000)}:all=1"]
            fl.append(f"[{n}:a]{','.join(chain)}[l{n}]")
        fl.append("".join(f"[l{n}]" for n in range(len(sel))) + f"amix=inputs={len(sel)}:normalize=0:duration=longest,apad=whole_dur={length:.4f},atrim=0:{length:.4f}[m]")
        run(args + ["-filter_complex", ";".join(fl), "-map", "[m]", "-c:a", "pcm_f32le", path])
        return path

    pre = mixdown(layers, os.path.join(PARTS, "premaster.wav"))
    # the two buses on their own (same gains): the music bed against everything else (game sound, effects, text sounds)
    bus = {}
    for name, sel in (("music", [l for l in layers if l[4] == "music bed"]), ("effects", [l for l in layers if l[4] != "music bed"])):
        bus[name] = loudness(mixdown(sel, os.path.join(PARTS, f"bus_{name}.wav")))[0]
    print(f"buses before the master: music {bus['music']:.1f} LUFS, effects {bus['effects']:.1f} LUFS "
          f"(music {bus['music'] - bus['effects']:+.1f} LU against the effects)")

    # master: gain to the target and a true-peak limiter (4x oversampled), no compressor: the balance is set per cue, so
    # only the transients of the hits touch the limiter. Further passes correct what the limiter took off.
    i0, p0, _ = loudness(pre, true_peak=True)
    print(f"premaster: {i0:.1f} LUFS, true peak {p0:.1f} dBTP")
    out = os.path.join(VID, "pitch_audio.wav")
    lim = 10 ** (LIMIT_DBTP / 20)
    g = TARGET_LUFS - i0
    for _ in range(5):
        run(["ffmpeg", "-v", "error", "-y", "-i", pre, "-af",
             f"volume={g:.2f}dB,aresample={SR * 4},alimiter=limit={lim:.4f}:attack=5:release=120:level=disabled,aresample={SR}",
             "-c:a", "pcm_s24le", out])
        i, p, lra = loudness(out, true_peak=True)
        if abs(i - TARGET_LUFS) < 0.15:
            break
        g += TARGET_LUFS - i
    print(f"master: {out}\n  {i:.1f} LUFS integrated, true peak {p:.1f} dBTP, LRA {lra:.1f} LU, {length:.2f} s (master gain {g:+.1f} dB)")

    if "--mux" in argv:
        video = argv[argv.index("--video") + 1] if "--video" in argv else os.path.join(VID, "pitch_film.mp4")
        mp4 = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(VID, "pitch.mp4")
        run(["ffmpeg", "-v", "error", "-y", "-i", video, "-i", out, "-map", "0:v:0", "-map", "1:a:0", "-c:v", "copy",
             "-c:a", "aac", "-b:a", "256k", "-ar", str(SR), "-movflags", "+faststart", "-shortest", mp4])
        i, p, _ = loudness(mp4, true_peak=True)
        print(f"muxed: {mp4}  ({i:.1f} LUFS, true peak {p:.1f} dBTP after AAC)")
        if "--web" in argv:  # smaller copy for the web: same 1080p60 picture at a fixed bitrate, AAC 192 kb/s
            web = os.path.splitext(mp4)[0] + "_web.mp4"
            log = os.path.join(tempfile.mkdtemp(), "x264")
            enc = ["-c:v", "libx264", "-preset", "slow", "-tune", "grain", "-b:v", f"{WEB_KBPS}k", "-maxrate", f"{WEB_KBPS * 2}k",
                   "-bufsize", f"{WEB_KBPS * 4}k", "-pix_fmt", "yuv420p", "-r", "60", "-passlogfile", log]
            run(["ffmpeg", "-v", "error", "-y", "-i", video] + enc + ["-pass", "1", "-an", "-f", "null", "-"])
            run(["ffmpeg", "-v", "error", "-y", "-i", video, "-i", out, "-map", "0:v:0", "-map", "1:a:0"] + enc +
                ["-pass", "2", "-c:a", "aac", "-b:a", "192k", "-ar", str(SR), "-movflags", "+faststart", "-shortest", web])
            i, p, _ = loudness(web, true_peak=True)
            print(f"web:   {web}  ({os.path.getsize(web) / 1e6:.1f} MB, {i:.1f} LUFS, true peak {p:.1f} dBTP)")


if __name__ == "__main__":
    main()
