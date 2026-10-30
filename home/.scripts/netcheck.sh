#!/usr/bin/env bash
#
# netcheck.sh — is my Wi-Fi bad, and if so, whose fault is it?
#
# WHY THIS EXISTS
# ---------------
# "The internet is slow" is never one problem. It is one of four, and they need
# completely different fixes. This script separates them, in order, so you never
# waste time rebooting a router when the fault is your laptop's Wi-Fi driver.
#
# The four layers, nearest to furthest:
#
#   1. YOUR RADIO      the Wi-Fi card and its driver on this machine
#   2. THE AIR         the 2.4/5 GHz spectrum you share with neighbours + Bluetooth
#   3. YOUR ROUTER     the FritzBox and the LAN behind it
#   4. THE INTERNET    everything past your router (the ISP)
#
# THE CENTRAL TRICK: ping your own router first.
#
# Your router sits one hop away, over Wi-Fi. If the round-trip to *that* is bad,
# every website will also be bad — but the cause is entirely local and the ISP is
# innocent. Only if the router is fast AND the internet is slow is it the ISP.
# Almost everyone skips this step and blames the wrong thing.
#
# HOW IT MEASURES
# ---------------
# - Latency is judged by SPREAD, not average. A link that answers in 1 ms and
#   sometimes 400 ms averages out to "fine" while feeling broken. So we report
#   percentiles: p50 (typical), p90, p99 (the bad moments) and max.
# - Retry counters are sampled as a DELTA across the test window, not read as the
#   since-boot total. The cumulative number includes hours of healthy traffic and
#   hides a problem that started ten minutes ago.
#
# USAGE:  ~/.scripts/netcheck.sh          normal run (~40 s)
#         ~/.scripts/netcheck.sh quick    shorter run (~15 s)

set -uo pipefail

# ── colours, but only when writing to a real terminal (so piping to a file
#    or to grep produces clean text instead of escape codes) ──────────────────
if [ -t 1 ]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[1m'; D=$'\e[2m'; N=$'\e[0m'
else
  R=""; G=""; Y=""; B=""; D=""; N=""
fi

ok()   { echo "  ${G}✓${N} $*"; }
warn() { echo "  ${Y}!${N} $*"; }
bad()  { echo "  ${R}✗${N} $*"; }
head_() { echo; echo "${B}$*${N}"; }

COUNT=100; INTERVAL=0.2
[ "${1:-}" = "quick" ] && COUNT=40

# ── work out which interface and gateway we are actually using, rather than
#    hardcoding wlan0 / 192.168.178.1 — this keeps working on another network ──
GW=$(ip route show default | awk '{print $3; exit}')
IFACE=$(ip route show default | awk '{print $5; exit}')

if [ -z "$GW" ]; then
  bad "No default route — you are not connected to any network at all."
  exit 1
fi

# Is this interface wireless? /sys exposes a 'wireless' dir only for Wi-Fi NICs.
IS_WIFI=0
[ -d "/sys/class/net/$IFACE/wireless" ] && IS_WIFI=1

echo "${B}netcheck${N} ${D}— interface $IFACE, gateway $GW${N}"

# ═══════════════════════════════════════════════════════════════════════════
# LAYER 1+2 — the radio: signal, speed, and how often frames need resending
# ═══════════════════════════════════════════════════════════════════════════
# Read the retry counters BEFORE the ping test so we can diff them afterwards
# and see retries caused by *this* test rather than by everything since boot.
RETRY_BEFORE=0; PKT_BEFORE=0
if [ "$IS_WIFI" = 1 ]; then
  head_ "1. Your Wi-Fi radio"

  LINK=$(iw dev "$IFACE" link 2>/dev/null)
  STA=$(iw dev "$IFACE" station dump 2>/dev/null)

  SSID=$(echo "$LINK"  | awk -F': ' '/SSID/{print $2}')
  FREQ=$(echo "$LINK"  | awk '/freq/{print $2}')
  SIG=$(echo "$STA"    | awk '/^\tsignal:/{print $2}')
  RATE=$(echo "$LINK"  | awk -F': ' '/tx bitrate/{print $2}' | cut -d' ' -f1)
  FAILED=$(echo "$STA" | awk '/tx failed/{print $3}')
  RETRY_BEFORE=$(echo "$STA" | awk '/tx retries/{print $3}')
  PKT_BEFORE=$(echo "$STA"   | awk '/tx packets/{print $3}')

  # Frequency tells you the band. 2.4 GHz is the crowded one: it has only three
  # non-overlapping channels (1, 6, 11), it penetrates walls so you hear every
  # neighbour, and Bluetooth shares it. 5 GHz has ~25 clean channels.
  if [ -n "$FREQ" ] && [ "${FREQ%%.*}" -lt 2500 ]; then
    CH=$(( (${FREQ%%.*} - 2407) / 5 ))
    warn "Band: ${R}2.4 GHz${N} (channel $CH) — the congested band. 5 GHz is much better if offered."
  else
    ok "Band: 5 GHz — the uncongested band."
  fi
  echo "     SSID $SSID, link rate ${RATE:-?} Mbit/s"

  # SIGNAL STRENGTH, in dBm. Negative; closer to zero is stronger.
  #   -30..-60  strong      -60..-67  usable      -67..-75  weak      below -75  bad
  # Caveat worth knowing: signal strength is NOT link quality. What decides
  # whether a frame survives is signal MINUS noise. A loud signal in a loud room
  # still fails. Most Linux drivers do not report the noise floor at all, which
  # is why a link can look "excellent" here and still drop packets.
  if [ -n "$SIG" ]; then
    S=${SIG%.*}
    if   [ "$S" -ge -60 ]; then ok   "Signal: ${SIG} dBm — strong."
    elif [ "$S" -ge -67 ]; then warn "Signal: ${SIG} dBm — usable but not great. Move closer if you can."
    else                        bad  "Signal: ${SIG} dBm — weak. This alone will cause stalls."
    fi
  fi

  # tx failed = frames the card retried to its limit and then THREW AWAY.
  # This is real, unrecoverable loss at the radio layer. Healthy is 0.
  # A number that climbs while you sit still usually means the driver has got
  # itself into a bad state — on this machine, reloading it or rebooting fixed it.
  if [ "${FAILED:-0}" -eq 0 ]; then
    ok "Dropped frames (tx failed): 0 — the radio is not giving up on anything."
  else
    bad "Dropped frames (tx failed): $FAILED — real loss at the radio layer."
    echo "     ${D}If this keeps climbing: sudo modprobe -r mt7925e && sudo modprobe mt7925e${N}"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# LAYER 3 — your own router. THE most important measurement in this script.
# ═══════════════════════════════════════════════════════════════════════════
head_ "2. Your router ($GW) — one hop away, over Wi-Fi"
echo "   ${D}sending $COUNT packets…${N}"

# -i 0.2 sends 5/second. The default of 1/second is too slow to catch the short
# bursts of interference that make browsing feel bad — at 1/s you can easily
# report "0% loss" on a link that stalls for two seconds at a time.
PING_OUT=$(ping -c "$COUNT" -i "$INTERVAL" -W 2 "$GW" 2>&1)
LOSS=$(echo "$PING_OUT" | grep -oE '[0-9.]+% packet loss' | grep -oE '[0-9.]+' | head -1)
TIMES=$(echo "$PING_OUT" | grep -oE 'time=[0-9.]+' | cut -d= -f2 | sort -n)

if [ -z "$TIMES" ]; then
  bad "No replies at all from your own router. The Wi-Fi link is down or blocked."
  exit 1
fi

# Percentiles beat averages here: they show the bad tail that an average hides.
read -r P50 P90 P99 PMAX PMIN OVER <<<"$(echo "$TIMES" | awk '
  {a[NR]=$1}
  END{
    o=0; for(i=1;i<=NR;i++) if(a[i]>50) o++
    print a[int(NR*0.5)], a[int(NR*0.9)], a[int(NR*0.99)], a[NR], a[1], int(o*100/NR)
  }')"

echo "     min ${PMIN}ms | p50 ${P50}ms | p90 ${P90}ms | p99 ${P99}ms | max ${PMAX}ms"

# PACKET LOSS to your own router should be exactly zero. It is one hop over
# your own equipment; anything above 0% is a broken link, not "normal internet".
if   [ "${LOSS%.*}" -eq 0 ] 2>/dev/null; then ok   "Packet loss: 0% — nothing is being dropped."
elif [ "${LOSS%.*}" -lt 3 ] 2>/dev/null; then warn "Packet loss: ${LOSS}% — low but should be 0 to your own router."
else                                          bad  "Packet loss: ${LOSS}% — the Wi-Fi link is dropping traffic."
fi

# LATENCY. A wired LAN answers in well under 1 ms. Good Wi-Fi answers in 1-5 ms.
# The gap between min and p99 is the real story: if min is 1 ms, the link is
# *capable* of being instant, so a high p99 means something is intermittently
# taking the airtime away — neighbours, Bluetooth, or a busy device of your own.
if   [ "${P50%.*}" -le 5 ]  2>/dev/null; then ok   "Typical latency: ${P50}ms — good."
elif [ "${P50%.*}" -le 25 ] 2>/dev/null; then warn "Typical latency: ${P50}ms — sluggish for one hop."
else                                          bad  "Typical latency: ${P50}ms — bad for your own router."
fi

if [ "$OVER" -le 2 ]; then ok   "Stalls: ${OVER}% of packets over 50ms."
else                       bad  "Stalls: ${OVER}% of packets over 50ms — this is what you feel as lag."
fi

# Now diff the retry counters. Wi-Fi ACKs every frame; no ACK means resend.
# Retries rescue the packet but cost time, so a high retry rate shows up as
# jitter rather than loss — it is the usual explanation for "0% loss but laggy".
if [ "$IS_WIFI" = 1 ]; then
  STA2=$(iw dev "$IFACE" station dump 2>/dev/null)
  RETRY_AFTER=$(echo "$STA2" | awk '/tx retries/{print $3}')
  PKT_AFTER=$(echo "$STA2"   | awk '/tx packets/{print $3}')
  DR=$(( ${RETRY_AFTER:-0} - ${RETRY_BEFORE:-0} ))
  DP=$(( ${PKT_AFTER:-0}   - ${PKT_BEFORE:-0} ))
  if [ "$DP" -gt 0 ]; then
    PCT=$(( DR * 100 / DP ))
    if   [ "$PCT" -le 5 ]  ; then ok   "Retransmissions during test: ${PCT}% — the air is quiet."
    elif [ "$PCT" -le 20 ] ; then warn "Retransmissions during test: ${PCT}% — the air is busy."
    else                          bad  "Retransmissions during test: ${PCT}% — heavy interference or contention."
    fi
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# LAYER 4 — the internet. Only meaningful once layer 3 is known to be healthy.
# ═══════════════════════════════════════════════════════════════════════════
head_ "3. The internet (1.1.1.1) — everything past your router"
NET_OUT=$(ping -c 20 -i 0.2 -W 2 1.1.1.1 2>&1)
NLOSS=$(echo "$NET_OUT" | grep -oE '[0-9.]+% packet loss' | grep -oE '[0-9.]+' | head -1)
NAVG=$(echo "$NET_OUT" | grep -oE 'min/avg/max[^=]*= [0-9./]+' | sed 's|.*= ||' | cut -d/ -f2)
echo "     loss ${NLOSS:-?}% | avg ${NAVG:-?}ms"

# THE VERDICT. Subtract the local damage from the internet number: whatever is
# left is genuinely the ISP's. If the router hop is already 90 ms, a 117 ms
# internet ping means the ISP contributed 27 ms — i.e. the ISP is fine.
if [ -n "$NAVG" ] && [ -n "$P50" ]; then
  DIFF=$(awk -v a="$NAVG" -v b="$P50" 'BEGIN{printf "%.0f", a-b}')
  echo
  echo "${B}Verdict${N}"
  if [ "${P50%.*}" -gt 25 ] 2>/dev/null || [ "${LOSS%.*}" -gt 0 ] 2>/dev/null; then
    bad "The fault is LOCAL — your own router hop is already bad."
    echo "     ${D}The ISP only adds ~${DIFF}ms on top. Fixing the Wi-Fi fixes everything.${N}"
  elif [ "$DIFF" -gt 60 ]; then
    warn "Wi-Fi is healthy but the internet adds ${DIFF}ms — this one really is the ISP/uplink."
  else
    ok "Both hops healthy — nothing wrong with the network right now."
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# WHO ELSE IS ON YOUR CHANNEL
# ═══════════════════════════════════════════════════════════════════════════
# 2.4 GHz has only three channels that do not overlap: 1, 6 and 11. Anything in
# between bleeds into two of them. Sharing a channel means taking turns, so the
# fix for a crowded channel is to move to an empty one.
if [ "$IS_WIFI" = 1 ] && command -v nmcli >/dev/null; then
  head_ "4. Who you share the air with"
  nmcli dev wifi rescan >/dev/null 2>&1
  sleep 4
  nmcli -t -f SSID,CHAN,SIGNAL dev wifi list 2>/dev/null |
    awk -F: -v y="$SSID" '
      $2!="" && $2<=14 {
        n[$2]++; s[$2]+=$3
        if ($1==y) mine=$2
        list[$2]=list[$2] sprintf("       %-22s %s%%\n", ($1==""?"(hidden)":$1), $3)
      }
      END{
        printf "     2.4 GHz networks per channel:\n"
        for (c=1;c<=13;c++) if (n[c]) printf "       ch %-3s %d network(s)%s\n", c, n[c], (c==mine?"   <- YOU":"")
        # Score the three non-overlapping channels by nearby signal, weighted by
        # how much they overlap (a network 5 channels away barely matters).
        best=""; bs=999999
        for (c=1;c<=11;c+=5) {
          sc=0
          for (k=1;k<=13;k++) if (n[k]) { d=(k>c?k-c:c-k); if (d<=4) sc += s[k]*(5-d)/5 }
          printf "     channel %-3s congestion score: %d\n", c, sc
          # <= not < : on a tie this keeps the LAST (highest) channel. 6 is the
          # most common factory default, so an empty 11 is the safer parking
          # spot than an equally empty 6 — a new neighbour AP will land on 6.
          if (sc<=bs) { bs=sc; best=c }
        }
        if (mine!=best) printf "     -> move your router from channel %s to channel %s\n", mine, best
        else            printf "     -> channel %s is already the best available\n", mine
      }'
fi

echo
echo "${D}Router settings: http://fritz.box -> Wi-Fi -> Radio Channel${N}"
