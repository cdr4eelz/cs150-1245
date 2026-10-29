#!/usr/bin/env bash
# Run one compiled sim-icarus test and judge it. Called by the Makefile:
#   run-test.sh <name> <build-dir>      (environment: see the Makefile's TEST_template)
# Writes <build-dir>/<name>.log (tee'd) and <build-dir>/<name>.status
# (PASS, FAIL, XFAIL or XPASS). Exit 0 for PASS/XFAIL, 1 for FAIL/XPASS.
set -o pipefail
name=$1; build=$2
log="$build/$name.log"; status="$build/$name.status"
mkdir -p "$build/$name"
# shellcheck disable=SC2086
for f in $RUNFILES; do cp -f "$f" "$build/$name/" || exit 1; done
cd "$build/$name" || exit 1

if [ -n "$QUIET_RE" ]; then
  # Drop known-noise lines from the log but say how many were dropped.
  filter() { awk -v re="$QUIET_RE" '$0 ~ re {n++; next} {print; fflush()} END {if (n) printf "(sim-icarus: filtered %d lines matching /%s/)\n", n, re}'; }
else
  filter() { cat; }
fi

# shellcheck disable=SC2086
timeout "${TIMEOUT:-600}" "${VVP:-vvp}" -n "$name.vvp" $PLUSARGS 2>&1 | filter | tee "../$name.log"
st=$?

why=""
if [ $st -eq 124 ]; then why="timed out after ${TIMEOUT:-600}s"
elif [ $st -ne 0 ]; then why="vvp exit $st"
elif [ -n "$FAIL_RE" ] && grep -Eq -- "$FAIL_RE" "../$name.log"; then why="log matches /$FAIL_RE/"
elif ! grep -Eq -- "$PASS_RE" "../$name.log"; then why="no line matching /$PASS_RE/"
fi

if [ -n "$XFAIL" ]; then
  if [ -n "$why" ]; then echo XFAIL > "../$name.status"; echo "SIM-ICARUS XFAIL: $name (expected failure: $XFAIL; $why)"; exit 0
  else echo XPASS > "../$name.status"; echo "SIM-ICARUS XPASS: $name passed but is marked XFAIL ($XFAIL); remove $name.XFAIL from tests/$name.mk"; exit 1; fi
fi
if [ -n "$why" ]; then echo FAIL > "../$name.status"; echo "SIM-ICARUS FAIL: $name ($why)"; exit 1; fi
echo PASS > "../$name.status"; echo "SIM-ICARUS PASS: $name"
