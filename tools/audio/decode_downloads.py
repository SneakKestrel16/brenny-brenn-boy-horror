"""Decode Freesound HQ preview mp3s (SoX here has no mp3): uv run --with miniaudio --with numpy python decode_downloads.py <in dir> <out dir>."""
import sys, glob, os, wave, miniaudio, numpy as np
for f in sorted(glob.glob(sys.argv[1]+"/*.mp3")):
    d = miniaudio.mp3_read_file_f32(f)
    a = np.array(d.samples, dtype=np.float32).reshape(-1, d.nchannels)
    sr = d.sample_rate
    m = a.mean(1)
    if sr != 48000:
        x = np.arange(0, len(m)/sr, 1/48000); m = np.interp(x, np.arange(len(m))/sr, m).astype(np.float32)
    out = os.path.join(sys.argv[2], os.path.basename(f)[:-4] + ".wav")
    with wave.open(out, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(48000)
        w.writeframes((np.clip(m,-1,1)*32767).astype("<i2").tobytes())
    F = np.abs(np.fft.rfft(m)); fr = np.fft.rfftfreq(len(m), 1/48000)
    e = lambda lo, hi: (F[(fr>=lo)&(fr<hi)]**2).sum()
    t = e(0, 24000) + 1e-12
    print(os.path.basename(f), f"{len(m)/48000:.2f}s pk{20*np.log10(abs(m).max()+1e-9):.1f} rms{20*np.log10(np.sqrt((m**2).mean())+1e-9):.1f} ch{d.nchannels} sr{sr} <80:{e(0,80)/t:.2f} 80-500:{e(80,500)/t:.2f} .5-2k:{e(500,2000)/t:.2f} >2k:{e(2000,24000)/t:.2f}")
