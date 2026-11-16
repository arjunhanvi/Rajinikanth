"""Synthesises every sound and music cue in the game. All audio is original and
procedurally generated: python3 tools/gen_audio.py  (needs numpy + ffmpeg)"""
import numpy as np, wave, subprocess, os
SR = 22050
OUT = "assets/audio/"
rng = np.random.default_rng(2002)

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.01, r=0.1):
    e = np.ones(n); na = max(int(SR * a), 1); nr = max(int(SR * r), 1)
    e[:na] = np.linspace(0, 1, na); e[-nr:] *= np.linspace(1, 0, nr); return e
def lp(x, k):
    y = np.empty_like(x); acc = 0.0
    for i in range(len(x)): acc += k * (x[i] - acc); y[i] = acc
    return y
def lpf(x, cutoff):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR); X *= 1 / (1 + (f / cutoff) ** 4); return np.fft.irfft(X, len(x))
def hpf(x, cutoff):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR); X *= 1 - 1 / (1 + (f / cutoff) ** 4); return np.fft.irfft(X, len(x))
def noise(d): return rng.uniform(-1, 1, int(SR * d))
def norm(x, peak=0.9): return x / (np.abs(x).max() + 1e-9) * peak
def loopable(x, fade=0.4):
    n = int(SR * fade); w = np.linspace(0, 1, n); y = x[n:].copy(); y[-n:] = y[-n:] * (1 - w) + x[:n] * w; return y
def save(name, x, ogg=False):
    x = np.clip(x, -1, 1); p = OUT + name + ".wav"
    with wave.open(p, "wb") as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(SR); f.writeframes((x * 32000).astype(np.int16).tobytes())
    if ogg:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", p, "-c:a", "libvorbis", "-q:a", "3", OUT + name + ".ogg"], check=True); os.remove(p)
def mix(total, parts):
    out = np.zeros(int(SR * total) + SR * 4)
    for start, sig in parts:
        i = int(SR * start); out[i:i + len(sig)] += sig
    return out[:int(SR * total)]
def hz(semi, base=146.83): return base * 2 ** (semi / 12)  # base = D3
def pluck(f, d, bright=0.5):
    n = int(SR * d); p = int(SR / f); buf = rng.uniform(-1, 1, p); out = np.empty(n)
    for i in range(n):
        out[i] = buf[i % p]; buf[i % p] = (buf[i % p] + buf[(i + 1) % p]) * 0.5 * (0.992 + 0.006 * bright)
    return out * env(n, 0.002, 0.05)
def pad(f, d, det=0.006):
    x = t(d); s = sum(np.sin(2 * np.pi * f * (1 + k * det) * x + k) + 0.3 * np.sin(4 * np.pi * f * (1 + k * det) * x) for k in (-1, 0, 1))
    return s / 3 * env(len(x), d * 0.3, d * 0.4)
def flute(f, d):
    x = t(d); vib = 1 + 0.006 * np.sin(2 * np.pi * 5 * x) * np.clip(x * 2, 0, 1)
    s = np.sin(2 * np.pi * f * vib * x) + 0.25 * np.sin(4 * np.pi * f * vib * x) + 0.05 * lpf(noise(d), 3000)[:len(x)]
    return s * env(len(x), 0.08, 0.15)
def boom(d=2.0, f0=70):
    x = t(d); f = f0 * np.exp(-x * 3) + 32; ph = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(ph) + 0.3 * lpf(noise(d), 200)[:len(x)]) * np.exp(-x * 2.2)
def tick(f=900, d=0.06):
    x = t(d); return np.sin(2 * np.pi * f * x) * np.exp(-x * 60)
def drone(d, semi=-12):
    x = t(d); return (np.sin(2 * np.pi * hz(semi) * x) + 0.5 * np.sin(2 * np.pi * hz(semi + 7) * x) + 0.25 * np.sin(2 * np.pi * hz(semi + 12) * x + 0.3 * np.sin(x))) / 1.75

# Scale: D harmonic minor flavour (Keeravani-like): D E F G A Bb C#
KE = [0, 2, 3, 5, 7, 8, 11, 12, 14, 15]

def title_theme():
    L = 30.0; parts = [(0, drone(L) * 0.28 * env(int(SR * L), 3, 4))]
    mel = [(4.0, 7, 2.5), (6.5, 8, 1.0), (7.5, 7, 1.0), (8.5, 5, 1.2), (9.7, 3, 2.6), (13.0, 7, 1.2), (14.2, 11, 1.2), (15.4, 12, 3.2),
           (19.0, 15, 1.0), (20.0, 14, 1.0), (21.0, 12, 1.0), (22.0, 11, 0.8), (22.8, 8, 0.8), (23.6, 7, 4.5)]
    for s, n, d in mel:
        parts.append((s, flute(hz(n + 12), d) * 0.22)); parts.append((s, pluck(hz(n), min(d + 1, 3)) * 0.3))
    for s, n in [(4, 0), (9.7, -4), (13, -5), (15.4, 0), (19, 3), (23.6, 0)]:
        for k in (0, 7, 12 if n else 15): parts.append((s, pad(hz(n + k - 12), 5.0) * 0.12))
    parts.append((15.4, boom(3.0) * 0.9)); parts.append((23.6, boom(3.5, 60) * 0.8))
    for i in range(16): parts.append((15.4 + i * 0.5, boom(0.4, 110) * 0.18 * (1 if i % 4 == 0 else 0.5)))
    return norm(lpf(mix(L, parts), 6000), 0.85)

def city_theme():  # warm, slightly wry daytime loop
    bar = 2.4; L = bar * 8; parts = [(0, drone(L, -12) * 0.1)]
    chords = [0, 0, 5, 0, 8, 7, 5, 0]
    riff = [0, 3, 7, 3, 12, 7, 3, 7]
    for b, c in enumerate(chords):
        for i, r in enumerate(riff):
            parts.append((b * bar + i * bar / 8, pluck(hz(c + r), 0.9, 0.2) * 0.22))
        parts.append((b * bar, pad(hz(c - 12), bar * 1.1) * 0.1))
        parts.append((b * bar, boom(0.5, 90) * 0.12)); parts.append((b * bar + bar * 0.5, tick(300, 0.1) * 0.1))
    lead = [(0, 12, 1.2), (1.2, 14, 0.6), (1.8, 15, 1.8), (4.8, 12, 0.6), (5.4, 10, 0.6), (6.0, 8, 1.2), (7.2, 7, 2.0),
            (9.6, 15, 1.2), (10.8, 14, 0.6), (11.4, 12, 1.4), (14.4, 8, 0.6), (15.0, 7, 0.6), (15.6, 5, 0.6), (16.2, 3, 0.6), (16.8, 0, 2.0)]
    for s, n, d in lead: parts.append((s, flute(hz(n), d) * 0.12))
    return norm(loopable(lpf(mix(L + 0.4, parts), 5000)), 0.8)

def tension_theme():
    L = 16.0; x = t(L + 0.4); parts = [(0, (np.sin(2 * np.pi * hz(-24) * x) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.25 * x))) * 0.4)]
    for i in range(32):
        parts.append((i * 0.5, boom(0.3, 80) * (0.3 if i % 4 == 0 else 0.12)))
        if i % 8 in (3, 6): parts.append((i * 0.5 + 0.25, tick(1400, 0.05) * 0.1))
    for s, n in [(0, 0), (4, 1), (8, 0), (12, 3), (14, 1)]: parts.append((s, pad(hz(n), 4.2, 0.012) * 0.16))
    for s, n in [(2, 12), (6, 13), (10, 15), (13, 13)]: parts.append((s, pluck(hz(n), 2.0) * 0.18))
    return norm(loopable(lpf(mix(L + 0.4, parts), 4000)), 0.8)

def love_theme():
    bar = 3.0; L = bar * 6; parts = []
    prog = [(5, [0, 4, 7]), (0, [0, 3, 7]), (8, [0, 4, 7]), (3, [0, 4, 7]), (5, [0, 4, 7]), (7, [0, 4, 7])]
    for b, (root, tri) in enumerate(prog):
        for i in range(6): parts.append((b * bar + i * 0.5, pluck(hz(root + tri[i % 3] + (12 if i > 2 else 0)), 1.6, 0.1) * 0.2))
        parts.append((b * bar, pad(hz(root - 12), bar * 1.1) * 0.12))
    for s, n, d in [(0, 12, 1.5), (1.5, 14, 1.5), (3, 15, 2.5), (6, 17, 1.5), (7.5, 15, 1.5), (9, 14, 2.5), (12, 12, 1.5), (13.5, 10, 1.5), (15, 12, 2.8)]:
        parts.append((s, flute(hz(n), d) * 0.16))
    return norm(loopable(lpf(mix(L + 0.4, parts), 4500)), 0.75)

def slowmo_cue():
    L = 9.0; x = t(L); sweep = np.sin(2 * np.pi * np.cumsum(60 + 30 * np.exp(-x)) / SR) * np.exp(-x * 0.35) * 0.5
    parts = [(0, sweep), (0, boom(4, 50) * 0.9), (0.2, pad(hz(0), 8) * 0.2), (0.2, pad(hz(7), 8) * 0.14), (2.5, flute(hz(15), 2.5) * 0.14), (5.0, flute(hz(12), 3.5) * 0.14)]
    for i in range(7): parts.append((1 + i * 1.1, boom(0.5, 45) * 0.5))  # heartbeat
    return norm(lpf(mix(L, parts), 3000), 0.85)

def engine(base, rough, d=2.0):
    x = t(d + 0.4); s = sum(np.sin(2 * np.pi * base * k * x + rng.uniform(0, 6)) / k for k in range(1, 9))
    s = s * (0.7 + 0.3 * np.sign(np.sin(2 * np.pi * base * 0.5 * x))) + rough * lpf(noise(d + 0.4), 500)
    return norm(loopable(s), 0.7)
def horn(freqs, d=0.6):
    x = t(d); s = sum(np.sign(np.sin(2 * np.pi * f * x)) * 0.5 + np.sin(2 * np.pi * f * x) for f in freqs)
    return norm(lpf(s, 2500) * env(len(x), 0.02, 0.08), 0.8)
def whistle():
    x = t(0.9); f = 2100 + 150 * np.sin(2 * np.pi * 38 * x)
    return norm((np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.2 * hpf(noise(0.9), 3000)) * env(len(x), 0.02, 0.1) * (1 - 0.9 * ((x > 0.38) & (x < 0.48))), 0.7)
def bell():
    x = t(1.0); s = sum(np.sin(2 * np.pi * f * x) * np.exp(-x * dd) for f, dd in [(1320, 6), (2640, 9), (3980, 14)])
    one = s / 3; return norm(mix(1.3, [(0, one), (0.22, one)]), 0.7)
def ring():
    notes = [12, 15, 19, 15, 12, 15, 19, 24]; parts = [(i * 0.14, np.sign(np.sin(2 * np.pi * hz(n + 24) * t(0.12))) * env(int(SR * 0.12), 0.005, 0.02) * 0.4) for i, n in enumerate(notes)]
    one = mix(1.3, parts); return norm(np.concatenate([one, np.zeros(SR // 2)]), 0.6)
def rain():
    n = noise(6.4); s = hpf(lpf(n, 6000), 900) * 0.6 + lpf(noise(6.4), 300) * 0.5
    for _ in range(300):
        i = rng.integers(0, len(s) - 400); k = tick(rng.uniform(1500, 4000), 0.013); s[i:i + len(k)] += k * 0.25
    return norm(loopable(s), 0.6)
def city_amb():
    d = 12.4; s = lpf(noise(d), 350) * 1.2 + lpf(noise(d), 1200) * 0.15; x = t(d); s *= 0.8 + 0.2 * np.sin(2 * np.pi * 0.13 * x)
    parts = [(0, s)]
    for _ in range(9):
        st = rng.uniform(0.5, 11); f = rng.choice([330, 392, 440, 520]); parts.append((st, lpf(horn([f, f * 1.26], rng.uniform(0.2, 0.5)), 900) * rng.uniform(0.04, 0.12)))
    for _ in range(4): parts.append((rng.uniform(0.5, 11), lpf(engine(rng.uniform(40, 70), 0.5, 1.2) * env(int(SR * 1.2), 0.5, 0.5), 600) * 0.15))
    for _ in range(14): parts.append((rng.uniform(0.2, 11.5), tick(rng.uniform(2500, 4200), 0.05) * 0.03))  # birds / cycle bells
    return norm(loopable(mix(d, parts)), 0.55)
def night_amb():
    d = 8.4; x = t(d); cr = np.sin(2 * np.pi * 4200 * x) * (np.sin(2 * np.pi * 14 * x) > 0.3) * (np.sin(2 * np.pi * 0.7 * x) > -0.2) * 0.12
    s = cr + lpf(noise(d), 200) * 0.6; parts = [(0, s), (3.0, lpf(horn([300, 378], 0.4), 500) * 0.05)]
    for st in (1.5, 1.9, 6.1): parts.append((st, lpf(noise(0.25) * env(int(SR * 0.25), 0.01, 0.2), 900) * 0.08))  # far dog
    return norm(loopable(mix(d, parts)), 0.5)
def crowd():
    d = 6.4; s = np.zeros(int(SR * d))
    for _ in range(60):
        st = rng.integers(0, len(s) - SR); dur = rng.uniform(0.15, 0.5); f = rng.uniform(140, 320); x = t(dur)
        v = np.sin(2 * np.pi * f * x * (1 + 0.1 * np.sin(2 * np.pi * 6 * x))) * env(len(x), 0.03, 0.08); s[st:st + len(v)] += v * rng.uniform(0.2, 1)
    return norm(loopable(lpf(s, 1400) + lpf(noise(d), 500) * 0.4), 0.5)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("music_title", title_theme(), True); save("music_city", city_theme(), True); save("music_tension", tension_theme(), True)
    save("music_love", love_theme(), True); save("music_slowmo", slowmo_cue(), True)
    save("amb_city", city_amb(), True); save("amb_night", night_amb(), True); save("amb_rain", rain(), True); save("amb_crowd", crowd(), True)
    save("eng_car", engine(55, 0.6)); save("eng_bus", engine(34, 1.2)); save("eng_auto", engine(78, 1.5)); save("eng_bike", engine(95, 0.9))
    save("horn_car", horn([415, 523])); save("horn_bus", horn([220, 277], 0.9)); save("horn_auto", horn([620], 0.25))
    save("whistle", whistle()); save("bell", bell()); save("ring", ring())
    save("click", tick(1200, 0.05) * 0.6); save("blip", norm(mix(0.25, [(0, tick(900, 0.1)), (0.09, tick(1350, 0.12))]), 0.5))
    save("coin", norm(mix(0.5, [(0, tick(2400, 0.2)), (0.07, tick(3200, 0.3))]), 0.5))
    save("step", norm(lpf(noise(0.09), 700) * np.exp(-t(0.09) * 45), 0.5))
    save("punch", norm(boom(0.25, 140) + lpf(noise(0.25), 1500)[:int(SR * 0.25)] * np.exp(-t(0.25) * 30), 0.8))
    save("boom", norm(boom(3.0, 65), 0.9)); save("heart", norm(mix(0.9, [(0, boom(0.3, 55)), (0.28, boom(0.3, 48) * 0.7)]), 0.8))
    x = t(1.2); save("whoosh", norm(lpf(noise(1.2), 900 + 2500 * np.sin(np.pi * x / 1.2)[0]) * np.sin(np.pi * x / 1.2) ** 2, 0.6))
    x = t(1.1); save("screech", norm((np.sin(2 * np.pi * np.cumsum(1900 - 500 * x) / SR) * 0.5 + hpf(noise(1.1), 2000)[:len(x)] * 0.6) * env(len(x), 0.03, 0.4), 0.6))
    save("crash", norm(lpf(noise(0.7), 2500) * np.exp(-t(0.7) * 7) + boom(0.7, 100)[:int(SR * 0.7)], 0.85))
    save("door", norm(boom(0.2, 120), 0.6))
    x = t(4.0); save("thunder", norm(lpf(noise(4.0), 180)[:len(x)] * np.exp(-x * 0.9) * (1 + 0.5 * np.sin(2 * np.pi * 3 * x)), 0.9))
    save("sms", norm(mix(0.6, [(i * 0.16, np.sign(np.sin(2 * np.pi * 1760 * t(0.08))) * 0.4) for i in range(3)]), 0.5))
    save("shutter", norm(lpf(noise(0.8), 1800) * (np.sin(2 * np.pi * 22 * t(0.8)) > 0) * env(int(SR * 0.8), 0.02, 0.2), 0.5))
    print("audio ok", len(os.listdir(OUT)), "files")
