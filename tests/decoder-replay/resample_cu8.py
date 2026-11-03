#!/usr/bin/env python3
"""Resample 8-bit unsigned IQ (cu8) by a rational factor, stdlib only.

dump1090-fa 9.0 demodulates at a fixed 2.4 MS/s, but the classic Mode S
recording (antirez/dump1090 testfiles/modes1.bin) was captured at 2.0 MS/s.
This converts it with a windowed-sinc polyphase interpolator (I and Q
separately, so pulse shapes survive) at --up/--down = 6/5.

usage: resample_cu8.py IN OUT [--up 6] [--down 5] [--taps 16]
"""

import argparse
import array
import math
import sys


def kernel(up, taps):
    """Polyphase filter bank: one list of `taps` coefficients per phase."""
    half = taps // 2
    bank = []
    for p in range(up):
        frac = p / up
        coeffs = []
        for k in range(-half + 1, half + 1):
            x = k - frac
            s = 1.0 if x == 0 else math.sin(math.pi * x) / (math.pi * x)
            # Blackman window over the filter span.
            w = 0.42 + 0.5 * math.cos(math.pi * x / half) + 0.08 * math.cos(2 * math.pi * x / half)
            coeffs.append(s * max(w, 0.0))
        bank.append(coeffs)
    return bank


def resample(data, up, down, taps):
    i_in = [b - 127.5 for b in data[0::2]]
    q_in = [b - 127.5 for b in data[1::2]]
    n_in = len(i_in)
    half = taps // 2
    bank = kernel(up, taps)
    n_out = (n_in - taps) * up // down
    out = bytearray(2 * n_out)
    for n in range(n_out):
        pos = n * down + (half - 1) * up  # keep the whole kernel inside the input
        base, phase = divmod(pos, up)
        coeffs = bank[phase]
        start = base - half + 1
        si = 0.0
        sq = 0.0
        for k, c in enumerate(coeffs):
            si += c * i_in[start + k]
            sq += c * q_in[start + k]
        out[2 * n] = min(255, max(0, int(round(si + 127.5))))
        out[2 * n + 1] = min(255, max(0, int(round(sq + 127.5))))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("infile")
    ap.add_argument("outfile")
    ap.add_argument("--up", type=int, default=6)
    ap.add_argument("--down", type=int, default=5)
    ap.add_argument("--taps", type=int, default=16)
    args = ap.parse_args()
    with open(args.infile, "rb") as f:
        data = array.array("B", f.read())
    out = resample(data, args.up, args.down, args.taps)
    with open(args.outfile, "wb") as f:
        f.write(out)
    print(f"{len(data) // 2} -> {len(out) // 2} IQ samples", file=sys.stderr)


if __name__ == "__main__":
    main()
