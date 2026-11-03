#!/usr/bin/env python3
"""Synthesize 978 MHz UAT ADS-B downlink frames as 8-bit unsigned IQ (cu8).

This is a SYNTHESIZED test signal, not an over-the-air recording: no
reliably hosted UAT IQ recording exists. It is built from the published
signal format so dump978-fa can be exercised without a receiver:

- payload per DO-282B: HDR (payload type, address qualifier, 24-bit
  address) and State Vector (lat/lon, altitude, NIC, air/ground, velocity),
  plus Mode Status (emitter category, base-40 callsign) in the long frame;
- Reed-Solomon over GF(256), field polynomial 0x187, first consecutive root
  120, primitive element 1: RS(30,18) for the Basic frame (payload type 0)
  and RS(48,34) for the Long frame (payload type 1);
- 36-bit downlink sync word 0xEACDDA4E2 before the coded bits;
- continuous-phase binary FSK at 1.041667 Mbit/s with modulation index
  h = 0.6 (+/-312.5 kHz), sampled at 2.083333 MS/s (2 samples per bit), with
  a fractional-sample timing offset, carrier phase offset and seeded
  Gaussian noise so the demodulator does not see an idealized grid.

Stdlib only. Output is deterministic for a given --seed.

usage: uat_gen.py OUT.cu8 [--address 0xA1B2C3] [--callsign N978OM] ...
"""

import argparse
import math
import random
import sys

SAMPLE_RATE = 2083333.0
SAMPLES_PER_BIT = 2
MOD_INDEX = 0.6
SYNC_WORD = 0xEACDDA4E2
SYNC_BITS = 36
# dump978-fa only demodulates a sync word with at least this many samples
# after it (36 sync bits + a whole 4416-bit uplink frame, at 2 samples/bit).
TRAILING_SAMPLES = (SYNC_BITS + 4416) * SAMPLES_PER_BIT

# DO-282B base-40 callsign alphabet, as dump978-fa decodes it.
BASE40 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ *??"


class ReedSolomon:
    """Phil Karn's encode_rs_char, as libfec's init_rs_char sets it up."""

    def __init__(self, gfpoly, fcr, prim, nroots, pad):
        self.nn = 255
        self.nroots = nroots
        self.pad = pad
        self.alpha_to = [0] * 256
        self.index_of = [0] * 256
        self.index_of[0] = self.nn  # A0, log of zero
        sr = 1
        for i in range(self.nn):
            self.index_of[sr] = i
            self.alpha_to[i] = sr
            sr <<= 1
            if sr & 0x100:
                sr ^= gfpoly
            sr &= 0xFF
        if sr != 1:
            raise ValueError("field generator polynomial is not primitive")
        self.alpha_to[self.nn] = 0
        self.fcr = fcr
        self.prim = prim
        genpoly = [0] * (nroots + 1)
        genpoly[0] = 1
        root = fcr * prim
        for i in range(nroots):
            genpoly[i + 1] = 1
            for j in range(i, 0, -1):
                if genpoly[j] != 0:
                    genpoly[j] = genpoly[j - 1] ^ self.alpha_to[self._mod(self.index_of[genpoly[j]] + root)]
                else:
                    genpoly[j] = genpoly[j - 1]
            genpoly[0] = self.alpha_to[self._mod(self.index_of[genpoly[0]] + root)]
            root += prim
        self.genpoly = [self.index_of[g] for g in genpoly]

    def _mod(self, x):
        while x >= self.nn:
            x -= self.nn
            x = (x >> 8) + (x & self.nn)
        return x

    def encode(self, data):
        if len(data) != self.nn - self.nroots - self.pad:
            raise ValueError("wrong data length")
        parity = [0] * self.nroots
        a0 = self.nn
        for byte in data:
            feedback = self.index_of[byte ^ parity[0]]
            if feedback != a0:
                for j in range(1, self.nroots):
                    parity[j] ^= self.alpha_to[self._mod(feedback + self.genpoly[self.nroots - j])]
            parity = parity[1:] + [0]
            if feedback != a0:
                parity[-1] = self.alpha_to[self._mod(feedback + self.genpoly[0])]
        return bytes(data) + bytes(parity)

    def syndromes_zero(self, codeword):
        """Self-check: the codeword vanishes at every generator root."""
        for i in range(self.nroots):
            root = self.alpha_to[self._mod((self.fcr + i) * self.prim)]
            s = 0
            for c in codeword:
                s = c ^ (0 if s == 0 else self.alpha_to[self._mod(self.index_of[s] + self.index_of[root])])
            if s:
                return False
        return True


class BitWriter:
    """Writes fields by DO-282B (byte, bit) positions, 1-based, MSB first."""

    def __init__(self, nbytes):
        self.buf = bytearray(nbytes)

    def put(self, first_byte, first_bit, last_byte, last_bit, value):
        fbi = (first_byte - 1) * 8 + first_bit - 1
        lbi = (last_byte - 1) * 8 + last_bit - 1
        width = lbi - fbi + 1
        if value < 0 or value >= (1 << width):
            raise ValueError(f"value {value} does not fit {width} bits")
        for k in range(width):
            bit = (value >> (width - 1 - k)) & 1
            pos = fbi + k
            if bit:
                self.buf[pos >> 3] |= 0x80 >> (pos & 7)


def state_vector(w, lat, lon, alt_ft, nic, north_kt, east_kt, vv_fpm):
    w.put(5, 1, 7, 7, int(round((lat % 360.0) * 16777216.0 / 360.0)) & 0x7FFFFF)
    w.put(7, 8, 10, 7, int(round((lon % 360.0) * 16777216.0 / 360.0)) & 0xFFFFFF)
    # 10,8 altitude type 0 = pressure altitude; 25 ft steps offset by -1000 ft.
    w.put(11, 1, 12, 4, alt_ft // 25 + 41)
    w.put(12, 5, 12, 8, nic)
    w.put(13, 1, 13, 2, 0)  # airborne, subsonic
    w.put(13, 4, 13, 4, 1 if north_kt < 0 else 0)
    w.put(13, 5, 14, 6, abs(north_kt) + 1)
    w.put(14, 7, 14, 7, 1 if east_kt < 0 else 0)
    w.put(14, 8, 16, 1, abs(east_kt) + 1)
    w.put(16, 2, 16, 2, 0)  # vertical velocity source: 0 = geometric
    w.put(16, 3, 16, 3, 1 if vv_fpm < 0 else 0)
    w.put(16, 4, 17, 4, abs(vv_fpm) // 64 + 1)


def mode_status(w, callsign, emitter_category):
    text = (callsign.upper() + " " * 8)[:8]
    idx = [BASE40.index(c) for c in text]
    w.put(18, 1, 19, 8, emitter_category * 1600 + idx[0] * 40 + idx[1])
    w.put(20, 1, 21, 8, idx[2] * 1600 + idx[3] * 40 + idx[4])
    w.put(22, 1, 23, 8, idx[5] * 1600 + idx[6] * 40 + idx[7])
    w.put(24, 4, 24, 6, 2)  # MOPS version 2 (DO-282B)
    w.put(24, 7, 24, 8, 3)  # SIL
    w.put(26, 1, 26, 4, 9)  # NACp
    w.put(26, 5, 26, 7, 1)  # NACv
    w.put(27, 7, 27, 7, 1)  # CSID: the field is a callsign


def payload(kind, address, args):
    w = BitWriter(18 if kind == "basic" else 34)
    w.put(1, 1, 1, 5, 0 if kind == "basic" else 1)  # payload type
    w.put(1, 6, 1, 8, 0)  # address qualifier: ADS-B target with ICAO address
    w.put(2, 1, 4, 8, address)
    state_vector(w, args.lat, args.lon, args.alt, 8, args.north, args.east, args.vv)
    if kind == "long":
        mode_status(w, args.callsign, 1)
    return bytes(w.buf)


def encode_frame(kind, address, args):
    if kind == "basic":
        rs = ReedSolomon(0x187, 120, 1, 12, 255 - 30)
    else:
        rs = ReedSolomon(0x187, 120, 1, 14, 255 - 48)
    code = rs.encode(payload(kind, address, args))
    if not rs.syndromes_zero(code):
        raise RuntimeError("Reed-Solomon self-check failed")
    return code


def corrupt(code, nerrors, rng):
    """Replace `nerrors` distinct coded bytes with different values."""
    code = bytearray(code)
    for pos in rng.sample(range(len(code)), nerrors):
        code[pos] ^= rng.randrange(1, 256)
    return bytes(code)


def to_bits(code):
    bits = [(SYNC_WORD >> (SYNC_BITS - 1 - i)) & 1 for i in range(SYNC_BITS)]
    for byte in code:
        bits.extend((byte >> (7 - k)) & 1 for k in range(8))
    return bits


def modulate(bits, out, rng, amplitude, noise, phase0, offset):
    """Append CPFSK samples for `bits` to bytearray `out`."""
    dphi_per_sample = math.pi * MOD_INDEX / SAMPLES_PER_BIT
    phase = phase0
    n = len(bits) * SAMPLES_PER_BIT
    for k in range(n):
        # Sample k lands `offset` samples into the bit grid; the phase ramps
        # linearly within each bit (rectangular frequency pulse).
        t = k + offset
        b = bits[min(int(t // SAMPLES_PER_BIT), len(bits) - 1)]
        phase += dphi_per_sample if b else -dphi_per_sample
        i = amplitude * math.cos(phase) + rng.gauss(0.0, noise)
        q = amplitude * math.sin(phase) + rng.gauss(0.0, noise)
        out.append(min(255, max(0, int(round(127.5 + i)))))
        out.append(min(255, max(0, int(round(127.5 + q)))))


def silence(out, rng, nsamples, noise):
    for _ in range(nsamples):
        out.append(min(255, max(0, int(round(127.5 + rng.gauss(0.0, noise))))))
        out.append(min(255, max(0, int(round(127.5 + rng.gauss(0.0, noise))))))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("outfile")
    ap.add_argument("--address", type=lambda s: int(s, 16), default=0xA1B2C3)
    ap.add_argument("--callsign", default="N978OM")
    ap.add_argument("--lat", type=float, default=38.88)
    ap.add_argument("--lon", type=float, default=-77.03)
    ap.add_argument("--alt", type=int, default=4500, help="pressure altitude, ft")
    ap.add_argument("--north", type=int, default=100, help="north velocity, kt")
    ap.add_argument("--east", type=int, default=-50, help="east velocity, kt")
    ap.add_argument("--vv", type=int, default=-640, help="vertical rate, ft/min")
    ap.add_argument("--repeat", type=int, default=3, help="basic+long frame pairs")
    ap.add_argument("--amplitude", type=float, default=60.0)
    ap.add_argument("--noise", type=float, default=4.0, help="noise sigma, counts")
    ap.add_argument("--errors", type=int, default=0,
                    help="byte errors per frame for the decoder's RS to fix (max 6 basic, 7 long)")
    ap.add_argument("--seed", type=int, default=978)
    args = ap.parse_args()

    rng = random.Random(args.seed)
    out = bytearray()
    silence(out, rng, 5000, args.noise)
    for _ in range(args.repeat):
        for kind in ("basic", "long"):
            code = encode_frame(kind, args.address, args)
            bits = to_bits(corrupt(code, args.errors, rng))
            modulate(bits, out, rng, args.amplitude, args.noise,
                     rng.uniform(0, 2 * math.pi), rng.uniform(0.05, 0.45))
            print(f"{kind}: {code.hex()}", file=sys.stderr)
            silence(out, rng, 3000, args.noise)
    silence(out, rng, TRAILING_SAMPLES + 2000, args.noise)
    with open(args.outfile, "wb") as f:
        f.write(out)
    print(f"{len(out) // 2} samples at {SAMPLE_RATE:.0f} S/s", file=sys.stderr)


if __name__ == "__main__":
    main()
