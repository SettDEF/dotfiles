#!/bin/bash
# noisewatch — know exactly what the machine was doing when the headset noise
# started.
#
# The HDB 630 noise has resisted diagnosis for months for one reason: by the
# time anyone looks, the moment is gone. Nothing in the audio stack logs it —
# measured repeatedly: zero PipeWire xruns, a clean kernel log, and the noise
# audible at -102 dB of digital attenuation, which means it does not travel
# through the digital path at all.
#
# So this does not try to detect the noise. It continuously records everything
# that could explain it into a ring buffer, and freezes that buffer the instant
# you say "now". The 90 seconds BEFORE you noticed are the evidence; everything
# after is already contaminated by you reacting.
#
#   noisewatch.sh daemon          sample forever (run by the systemd unit)
#   noisewatch.sh mark [reason]   freeze the ring + take a deep snapshot
#   noisewatch.sh report [dir]    read back the latest (or a given) capture
#   noisewatch.sh status          is it running, how big is the ring
#
# Deliberately cheap: the fast loop reads five small files under /proc and
# /sys and writes one CSV line. No subprocess per sample — a monitor that
# loads the machine would change the thing it is measuring.

set -uo pipefail

CARD_NAME="H630"
RING="/dev/shm/noisewatch.ring"
RING_MAX=180                     # samples kept; at 0.5s each that is 90s
OUT_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/noisewatch"
INTERVAL=0.5

# ── Finding the card ────────────────────────────────────────────────────────
# The index moves between boots, so never hardcode it.
card_index() {
    for d in /proc/asound/card[0-9]*; do
        [ -r "$d/id" ] || continue
        case "$(cat "$d/id" 2>/dev/null)" in
            *"$CARD_NAME"*|*H630*|*HDB*) echo "${d##*card}"; return 0 ;;
        esac
    done
    return 1
}

# ── The USB chain the headset hangs off ─────────────────────────────────────
# Resolved once: /sys/class/sound/cardN/device is the interface, its parent is
# the device, and each parent above that is a hub.
#
# This matters because the hub one level up negotiated 12 Mbit/s, not 480. A
# USB 2.0 hub at full speed either is not one or failed high-speed negotiation,
# and everything below it shares that 12 Mbit/s — including isochronous audio.
# If that renegotiates, or a hub suspends mid-stream, it shows up here.
USB_CHAIN=""
resolve_chain() {
    local ci="$1" p
    p=$(readlink -f "/sys/class/sound/card$ci/device" 2>/dev/null) || return 1
    p=$(dirname "$p")                       # interface -> device
    USB_CHAIN=""
    while [ -r "$p/speed" ]; do
        USB_CHAIN="$p${USB_CHAIN:+ }$USB_CHAIN"
        p=$(dirname "$p")
    done
    [ -n "$USB_CHAIN" ]
}

# ── One sample ──────────────────────────────────────────────────────────────
# Every field here is something that could plausibly move when the noise
# starts. Cheap to read, and meaningless in isolation — the point is the shape
# of all of them together across the 90s before the mark.
sample() {
    local ci="$1" now stream freq state delay load gpu temp online pkt
    now=$(date +%s.%N)

    stream="/proc/asound/card$ci/stream0"
    # The USB audio clock. A starved isochronous stream shows here as the
    # momentary frequency wandering off 48000 — and nowhere else at all.
    freq=$(grep -m1 "Momentary freq" "$stream" 2>/dev/null | grep -oE '[0-9]+ Hz' | tr -d ' Hz')
    pkt=$(grep -m1 "Packet Size" "$stream" 2>/dev/null | grep -oE '[0-9]+$')
    state=$(grep -m1 "^state:" "/proc/asound/card$ci/pcm0p/sub0/status" 2>/dev/null | awk '{print $2}')
    # Buffer delay in frames: jitter here is starvation before it is audible.
    delay=$(grep -m1 "^delay" "/proc/asound/card$ci/pcm0p/sub0/status" 2>/dev/null | awk '{print $3}')

    load=$(awk '{print $1}' /proc/loadavg)
    gpu=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)
    temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
    online=$(cat /sys/class/power_supply/A*/online 2>/dev/null | head -1)

    # The dock: link speed and power state of every hub between the headset and
    # the root, plus how many devices share its last segment.
    local speeds="" pwrs="" d n=0
    for d in $USB_CHAIN; do
        speeds="$speeds${speeds:+/}$(cat "$d/speed" 2>/dev/null)"
        pwrs="$pwrs${pwrs:+/}$(cat "$d/power/runtime_status" 2>/dev/null | cut -c1)"
    done
    # Siblings on the headset's own segment: contention for 12 Mbit/s.
    local leaf="${USB_CHAIN##* }" parent
    parent=$(dirname "$leaf")
    for d in "$parent"/*-*; do
        [ -r "$d/speed" ] && n=$((n + 1))
    done

    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$now" "${freq:-}" "${pkt:-}" "${state:-}" "${delay:-}" \
        "${load:-}" "${gpu:-}" "${temp:-}" "${online:-}" \
        "${speeds:-}" "${pwrs:-}" "$n"
}

cmd_daemon() {
    local ci
    ci=$(card_index) || { echo "noisewatch: HDB 630 not present; waiting" >&2; }
    echo "time,freq,packet,state,delay,load,gpu,temp_mC,ac,usb_speeds,usb_power,segment_devs" > "$RING.head"
    resolve_chain "$ci" || true
    : > "$RING"
    while true; do
        if [ -z "${ci:-}" ]; then
            ci=$(card_index) || { sleep 5; continue; }
            resolve_chain "$ci" || true     # paths change on re-enumeration
        fi
        # The card going away is itself worth recording.
        if [ ! -r "/proc/asound/card$ci/stream0" ]; then
            printf '%s,,,GONE,,,,,\n' "$(date +%s.%N)" >> "$RING"
            ci=""
        else
            sample "$ci" >> "$RING"
        fi
        # Trim in place. tail -n on a growing file every tick is wasteful, so
        # only when it has overgrown by half.
        local n; n=$(wc -l < "$RING")
        if [ "$n" -gt $((RING_MAX * 3 / 2)) ]; then
            tail -n "$RING_MAX" "$RING" > "$RING.tmp" && mv "$RING.tmp" "$RING"
        fi
        sleep "$INTERVAL"
    done
}

# ── The deep snapshot ───────────────────────────────────────────────────────
cmd_mark() {
    local reason="${1:-manual}"
    local ts dir ci
    ts=$(date +%Y%m%d-%H%M%S)
    dir="$OUT_ROOT/$ts"
    mkdir -p "$dir" || { echo "noisewatch: cannot write $dir" >&2; return 1; }
    ci=$(card_index) || ci=""

    echo "$reason" > "$dir/reason.txt"
    date -Iseconds > "$dir/when.txt"

    # 1. The 90 seconds before you noticed.
    { cat "$RING.head" 2>/dev/null; cat "$RING" 2>/dev/null; } > "$dir/ring.csv"

    # 2. The audio stack, right now.
    [ -n "$ci" ] && {
        cp "/proc/asound/card$ci/stream0" "$dir/usb-stream.txt" 2>/dev/null
        cp "/proc/asound/card$ci/pcm0p/sub0/status" "$dir/pcm-status.txt" 2>/dev/null
        cp "/proc/asound/card$ci/pcm0p/sub0/hw_params" "$dir/pcm-hwparams.txt" 2>/dev/null
        amixer -c "$ci" scontents > "$dir/alsa-mixer.txt" 2>/dev/null
    }
    pactl list sinks            > "$dir/pw-sinks.txt"        2>/dev/null
    pactl list short sink-inputs> "$dir/pw-streams.txt"      2>/dev/null
    timeout 5 pw-top -b -n 2    > "$dir/pw-top.txt"          2>/dev/null

    # 3. The USB path — the standing hypothesis. Speeds and the hub chain.
    lsusb -t                    > "$dir/usb-tree.txt"        2>/dev/null
    for p in 7-1 7-1.3 7-1.3.2 7-1.3.2.1; do
        d="/sys/bus/usb/devices/$p"
        [ -d "$d" ] && printf '%s speed=%s product=%s\n' \
            "$p" "$(cat "$d/speed" 2>/dev/null)" "$(cat "$d/product" 2>/dev/null)"
    done > "$dir/usb-chain.txt" 2>/dev/null

    # 4. Load and power at the moment — the noise tracks these, not the audio.
    {
        echo "loadavg: $(cat /proc/loadavg)"
        echo "gpu_busy: $(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)"
        for z in /sys/class/thermal/thermal_zone*; do
            printf '%s: %s = %s\n' "${z##*/}" "$(cat "$z/type" 2>/dev/null)" "$(cat "$z/temp" 2>/dev/null)"
        done
        echo "ac_online: $(cat /sys/class/power_supply/A*/online 2>/dev/null | head -1)"
        ps -eo pcpu,comm --sort=-pcpu --no-headers | head -8
    } > "$dir/load.txt" 2>/dev/null

    # 5. Radios. 2.4GHz interference was a live theory and needs ruling in or out.
    {
        rfkill list 2>/dev/null
        echo "--- recent bluetooth kernel lines ---"
        journalctl -k --since "-5 min" --no-pager 2>/dev/null | grep -ci bluetooth
        echo "--- adv-monitor registrations, lifetime ---"
        journalctl -u bluetooth --no-pager 2>/dev/null | grep -c "Adv Monitor app"
    } > "$dir/radios.txt" 2>/dev/null

    # 6. Kernel, last 5 minutes.
    journalctl -k --since "-5 min" --no-pager > "$dir/dmesg-5min.txt" 2>/dev/null

    # 7. THE DISCRIMINATOR.
    # Record what PipeWire is actually sending to the headset. If this is
    # silent while you can hear noise, the noise is generated after the
    # digital path — in the device or its analogue supply — and no amount of
    # software can touch it. That single fact decides where to look next, and
    # it has never been captured at the moment it mattered.
    local mon
    mon=$(pactl list short sinks 2>/dev/null | awk '/Sonova/{print $2".monitor"; exit}')
    if [ -n "$mon" ]; then
        timeout 8 parecord --device="$mon" --file-format=wav \
            --channels=2 --rate=48000 --format=s16le "$dir/digital.wav" &
        local pid=$!
        sleep 6; kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
    fi

    echo "$dir"
}

# ── Reading it back ─────────────────────────────────────────────────────────
cmd_report() {
    local dir="${1:-}"
    [ -z "$dir" ] && dir=$(ls -1d "$OUT_ROOT"/*/ 2>/dev/null | tail -1)
    [ -z "$dir" ] && { echo "noisewatch: no captures yet"; return 1; }
    dir="${dir%/}"

    echo "── $dir"
    echo "   when:   $(cat "$dir/when.txt" 2>/dev/null)"
    echo "   reason: $(cat "$dir/reason.txt" 2>/dev/null)"
    echo

    # The digital verdict: was PipeWire sending anything at all?
    if [ -f "$dir/digital.wav" ]; then
        python3 - "$dir/digital.wav" <<'PY'
import sys, wave, math, array
try:
    w = wave.open(sys.argv[1]); n = w.getnframes()
    d = array.array('h'); d.frombytes(w.readframes(n))
    if not d:
        print("   digital path: EMPTY capture"); raise SystemExit
    peak = max(abs(x) for x in d)
    rms = math.sqrt(sum(x*x for x in d)/len(d))
    db = lambda v: -120 if v <= 0 else 20*math.log10(v/32768)
    print(f"   digital path: peak {db(peak):6.1f} dBFS   rms {db(rms):6.1f} dBFS")
    if db(rms) < -80:
        print("   -> PipeWire was sending SILENCE. Noise heard during this")
        print("      window is generated after the digital stage: the device")
        print("      itself, or its power. Software cannot reach it.")
    else:
        print("   -> There IS signal in the digital path, so this capture")
        print("      cannot separate 'the noise is in the stream' from 'the")
        print("      noise is in the device'. For a decisive answer, pause")
        print("      playback and mark again while the noise is still audible:")
        print("      silence here + noise in your ears = the device or its")
        print("      power, and no software fix exists.")
except Exception as e:
    print("   digital path: unreadable —", e)
PY
    else
        echo "   digital path: not captured"
    fi
    echo

    # The clock: did the USB audio clock wander?
    python3 - "$dir/ring.csv" <<'PY'
import sys, csv
rows = list(csv.DictReader(open(sys.argv[1])))
if not rows:
    print("   ring: empty — was the daemon running?"); raise SystemExit
def nums(k):
    out = []
    for r in rows:
        try: out.append(float(r[k]))
        except (TypeError, ValueError): pass
    return out
freq = nums("freq"); delay = nums("delay"); load = nums("load"); gpu = nums("gpu")
print(f"   ring: {len(rows)} samples, {len(rows)*0.5:.0f}s before the mark")
if freq:
    lo, hi = min(freq), max(freq)
    print(f"   usb clock: {lo:.0f}-{hi:.0f} Hz", end="")
    print("   <- DRIFTED; a starved isochronous stream looks exactly like this"
          if hi - lo > 2 else "   (steady)")
if delay:
    lo, hi = min(delay), max(delay)
    # A quantum here is 1024 frames, and the delay breathing by half a
    # quantum is normal — an earlier threshold of 500 called that
    # "jittered" on a perfectly healthy capture. Starvation is a delay
    # collapsing toward zero or spiking by several quanta.
    verdict = ("   <- COLLAPSED toward zero: the device ran dry" if lo < 256
               else "   <- SPIKED by several quanta" if hi - lo > 4096
               else "   (normal breathing)")
    print(f"   buffer delay: {lo:.0f}-{hi:.0f} frames{verdict}")
if load: print(f"   load: {min(load):.2f}-{max(load):.2f}")
if gpu:  print(f"   gpu busy: {min(gpu):.0f}-{max(gpu):.0f}%")
states = {r["state"] for r in rows if r.get("state")}
print(f"   pcm states seen: {', '.join(sorted(states)) or 'none'}")
PY
    echo
    echo "   full capture: $dir"
}

cmd_status() {
    if pgrep -f "noisewatch.sh daemon" >/dev/null; then
        echo "daemon: running"
    else
        echo "daemon: NOT running"
    fi
    if [ -f "$RING" ]; then
        echo "ring:   $(wc -l < "$RING") samples (~$(( $(wc -l < "$RING") / 2 ))s)"
    else
        echo "ring:   empty"
    fi
    echo "captures: $(ls -1d "$OUT_ROOT"/*/ 2>/dev/null | wc -l) in $OUT_ROOT"
}

case "${1:-}" in
    daemon) cmd_daemon ;;
    mark)   shift; cmd_mark "${*:-manual}" ;;
    report) shift; cmd_report "${1:-}" ;;
    status) cmd_status ;;
    *) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
