#!/bin/sh
# Replays recorded and synthesized IQ through dump1090-fa and dump978-fa and
# checks that the expected aircraft come out. Used by
# .github/workflows/decoder-replay.yml; runs the same way on a workstation:
#
#   tests/decoder-replay/run.sh /path/to/dump1090 /path/to/dump978-fa [workdir]
#
# 1090 MHz input is a REAL over-the-air recording: testfiles/modes1.bin from
# antirez/dump1090 (BSD-3-Clause), 8-bit unsigned IQ at 2.0 MS/s, fetched at
# run time pinned by commit and sha256. dump1090-fa 9.0 only demodulates at
# 2.4 MS/s, so it is resampled 6/5 first (resample_cu8.py).
#
# 978 MHz input is SYNTHESIZED by uat_gen.py: no UAT IQ recording is hosted
# anywhere reliable. It checks the demodulator, Reed-Solomon decoder and
# payload decoder against frames built from the DO-282B format.
set -eu

DUMP1090=$1
DUMP978=$2
WORK=${3:-$(mktemp -d)}
HERE=$(cd "$(dirname "$0")" && pwd)
PY="python3 -I"

MODES1_URL=https://raw.githubusercontent.com/antirez/dump1090/efe64db3c6ba1520291331628a33c1e208e851a6/testfiles/modes1.bin
MODES1_SHA256=3a33e16025da8669149c780075950b4e908ca036ea21f9583c113f60d5fb3094

mkdir -p "$WORK"
cd "$WORK"

echo "== 1090 MHz: modes1.bin (real recording)"
if ! echo "$MODES1_SHA256  modes1.bin" | sha256sum -c --status 2>/dev/null; then
	curl -sSfL --retry 5 -o modes1.bin "$MODES1_URL"
	echo "$MODES1_SHA256  modes1.bin" | sha256sum -c -
fi
$PY "$HERE/resample_cu8.py" modes1.bin modes1-2400k.cu8
# dump1090-fa exits 1 ("Abnormal exit") at the end of any --ifile input, so
# its exit status is ignored; the checks below decide.
"$DUMP1090" --ifile modes1-2400k.cu8 --iformat UC8 --raw >1090-raw.txt 2>1090-raw.err || true
"$DUMP1090" --ifile modes1-2400k.cu8 --iformat UC8 >1090-verbose.txt 2>1090-verbose.err || true
# Expected set, from running dump1090-fa 9.0 on this file: one aircraft,
# 4D2023 (Air Malta AMC421, squawk 0112) descending through FL220 over southern
# Sicily; 312 CRC-clean messages and 25 globally decoded positions.
$PY "$HERE/check.py" 1090 1090-raw.txt 1090-verbose.txt \
	'{"min_messages": 300, "addresses": ["4d2023"], "ident": "AMC421", "squawk": "0112", "min_positions": 20}'

expect978() {
	# $1 = byte errors injected per frame, $2 = basic frames, $3 = long frames
	printf '{"address": "a1b2c3", "callsign": "N978OM", "position": {"lat": 38.87999, "lon": -77.03}, "altitude": 4500, "north": 100, "east": -50, "errors": %s, "basic": %s, "long": %s}' "$1" "$2" "$3"
}

for errors in 0 6 7; do
	echo "== 978 MHz: synthesized UAT, $errors byte errors per frame"
	$PY "$HERE/uat_gen.py" --errors "$errors" "uat-$errors.cu8"
	"$DUMP978" --stdin --format CU8 --json-stdout <"uat-$errors.cu8" >"978-$errors.json"
	case $errors in
	# 6 is the most a Basic frame's RS(30,18) can fix; at 7 only the Long
	# frames, RS(48,34), survive. This proves the decoder is really checking.
	7) $PY "$HERE/check.py" 978 "978-$errors.json" "$(expect978 7 0 3)" ;;
	*) $PY "$HERE/check.py" 978 "978-$errors.json" "$(expect978 "$errors" 3 3)" ;;
	esac
done

echo "All decoder replays passed."
