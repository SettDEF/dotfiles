#!/usr/bin/env python3
"""
dj808-map.py — work out what each of the DJ-808's 14 USB capture channels carries.

WHY THIS EXISTS
---------------
The Roland DJ-808 sends 14 channels of audio to the computer over USB, but it
does not tell the computer what any of them ARE. Linux asks the device for a
channel map and gets this back:

    FL FR FC LFE RL RR FLC FRC RC SL SR TC -- --

Those are generic surround-sound labels (Front Left, Front Right, Centre, LFE…)
that ALSA invents when a device declines to name its channels. They are
meaningless here — there is no "LFE" on a DJ mixer. The real assignment is
master, mic, the deck channels, the TR-S drum section and the line/phono inputs,
in an order the device never states.

So rather than trust a label or a manual, this MEASURES it: you record all 14
channels while making noise on one thing at a time, and whichever channel lights
up is the one carrying it.

HOW IT MEASURES
---------------
For each channel it reports three things, because one number cannot tell silence
from a channel that is connected but quiet:

  peak   the loudest single sample, in dBFS. Answers "did anything at all
         arrive on this channel?" Digital silence is -inf.
  rms    the average energy, in dBFS. Answers "how much is on it overall?"
         A channel with a high peak but very low RMS caught one transient —
         a drum hit — rather than continuous programme material.
  active what fraction of the recording was above the noise floor. This is what
         separates a live-but-idle input (near 0%) from one actually in use.

dBFS = decibels relative to full scale, so 0 dB is the loudest a digital signal
can be and everything real is negative. Roughly: above -20 dB is a hot signal,
-20 to -50 dB is normal programme material, below -60 dB is effectively silence
or bleed.

The pairing matters too. Audio hardware groups channels into stereo pairs, so
channels 1+2 are one source, 3+4 the next, and so on. The script prints them in
pairs and flags a pair as one source when both sides show similar energy.

USAGE
-----
    arecord -D hw:2,0 -c 14 -f S32_LE -r 48000 -d 60 cap.wav
    ./dj808-map.py cap.wav

Make noise on ONE source at a time while recording, and note roughly when you
did what — then read off which channel followed along.
"""

import sys
import wave
import numpy as np


def db(x: float) -> str:
    """Linear amplitude (0..1) to dBFS, printed. log(0) is undefined, so
    anything at or below zero is reported as digital silence instead."""
    return "  -inf  " if x <= 0 else f"{20 * np.log10(x):7.1f}"


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else "cap.wav"

    with wave.open(path, "rb") as w:
        ch, width, rate, n = (
            w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        )
        raw = w.readframes(n)

    if n == 0:
        print("The file is empty — the recording captured nothing.")
        return 1

    # 32-bit signed PCM. Read as int32, then scale to -1.0..+1.0 so the maths
    # below is independent of bit depth. 2**31 is full scale for int32.
    if width == 4:
        data = np.frombuffer(raw, dtype="<i4").astype(np.float64) / (2 ** 31)
    elif width == 2:
        data = np.frombuffer(raw, dtype="<i2").astype(np.float64) / (2 ** 15)
    else:
        print(f"Unhandled sample width: {width} bytes")
        return 1

    # The file is interleaved — one frame is all 14 channels back to back, so
    # the stream reads L,R,3,4,…,14,L,R,3,4,… Reshaping to (frames, channels)
    # turns that back into one column per channel.
    data = data.reshape(-1, ch)
    dur = data.shape[0] / rate

    print(f"{path}: {ch} channels, {rate} Hz, {dur:.1f}s\n")

    peaks = np.abs(data).max(axis=0)
    rms = np.sqrt((data ** 2).mean(axis=0))

    # "Active" fraction: how much of the time this channel was above a floor.
    # -60 dBFS (0.001) is comfortably above dither and converter noise but well
    # below any real signal, so it reads as "something was actually here".
    active = (np.abs(data) > 0.001).mean(axis=0) * 100

    print("  ch   peak dBFS   rms dBFS   active%   ")
    print("  ─────────────────────────────────────")
    for i in range(ch):
        bar = "█" * int(min(active[i], 100) / 5)
        flag = "  <-- SIGNAL" if peaks[i] > 0.001 else ""
        print(f"  {i+1:>2}   {db(peaks[i])}   {db(rms[i])}   {active[i]:6.1f}  {bar}{flag}")

    # Report stereo pairs. Two channels carrying one source show similar energy;
    # a big imbalance means they are separate mono sources that happen to be
    # adjacent, not a pair.
    print("\n  stereo pairs (a source usually occupies both sides):")
    for i in range(0, ch - 1, 2):
        l, r = peaks[i], peaks[i + 1]
        if max(l, r) <= 0.001:
            verdict = "silent"
        elif min(l, r) > 0.001 and abs(db_f(l) - db_f(r)) < 6:
            verdict = "ACTIVE — balanced, one stereo source"
        else:
            verdict = "ACTIVE — imbalanced, likely two mono sources"
        print(f"    ch {i+1:>2}+{i+2:<2}  {verdict}")

    live = [str(i + 1) for i in range(ch) if peaks[i] > 0.001]
    print(f"\n  channels carrying signal: {', '.join(live) if live else 'none'}")
    if not live:
        print("  Nothing arrived on any channel — check the TR-S was actually")
        print("  playing, and that its output is routed to the USB send.")
    return 0


def db_f(x: float) -> float:
    """dBFS as a number, for comparisons (db() returns a formatted string)."""
    return -999.0 if x <= 0 else 20 * float(np.log10(x))


if __name__ == "__main__":
    sys.exit(main())
