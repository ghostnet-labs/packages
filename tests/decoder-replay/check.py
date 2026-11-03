#!/usr/bin/env python3
"""Assertions for the decoder replay (see run.sh). Stdlib only."""

import json
import re
import sys


def fail(msg):
    print(f"FAIL: {msg}")
    sys.exit(1)


def check_1090(raw_path, verbose_path, args):
    # --raw prints one CRC-checked message per line as *<hex>;
    msgs = [l.strip()[1:-1] for l in open(raw_path) if l.startswith("*")]
    # DF11 (all-call reply), DF17 and DF18 (extended squitter) carry the
    # address in the clear; the other formats overlay it on the parity.
    addrs = sorted({m[2:8] for m in msgs if (int(m[:2], 16) >> 3) in (11, 17, 18)})
    text = open(verbose_path).read()
    idents = sorted(set(re.findall(r"^\s*Ident:\s+(\S+)", text, re.M)))
    squawks = sorted(set(re.findall(r"^\s*Squawk:\s+(\d{4})", text, re.M)))
    positions = len(re.findall(r"CPR decoding:\s+global", text))
    print(f"1090: {len(msgs)} messages, addresses {addrs}, idents {idents}, "
          f"squawks {squawks}, {positions} global CPR positions")
    if len(msgs) < args["min_messages"]:
        fail(f"expected at least {args['min_messages']} messages")
    if addrs != args["addresses"]:
        fail(f"expected addresses {args['addresses']}")
    if args["ident"] not in idents:
        fail(f"expected ident {args['ident']}")
    if args["squawk"] not in squawks:
        fail(f"expected squawk {args['squawk']}")
    if positions < args["min_positions"]:
        fail(f"expected at least {args['min_positions']} global CPR positions")


def check_978(json_path, args):
    frames = [json.loads(l) for l in open(json_path) if l.strip()]
    basic = [f for f in frames if "callsign" not in f]
    long_ = [f for f in frames if "callsign" in f]
    print(f"978: {len(basic)} basic + {len(long_)} long frames, "
          f"errors corrected {sorted({f['metadata']['errors'] for f in frames})}")
    if len(basic) != args["basic"] or len(long_) != args["long"]:
        fail(f"expected {args['basic']} basic and {args['long']} long frames")
    for f in frames:
        got = (f["address"], f.get("position"), f.get("pressure_altitude"),
               f.get("north_velocity"), f.get("east_velocity"), f["metadata"]["errors"])
        want = (args["address"], args["position"], args["altitude"],
                args["north"], args["east"], args["errors"])
        if got != want:
            fail(f"frame decoded as {got}, expected {want}")
    for f in long_:
        if f["callsign"] != args["callsign"]:
            fail(f"callsign {f['callsign']!r}, expected {args['callsign']!r}")


def main():
    mode = sys.argv[1]
    if mode == "1090":
        check_1090(sys.argv[2], sys.argv[3], json.loads(sys.argv[4]))
    elif mode == "978":
        check_978(sys.argv[2], json.loads(sys.argv[3]))
    else:
        fail(f"unknown mode {mode}")
    print("OK")


if __name__ == "__main__":
    main()
