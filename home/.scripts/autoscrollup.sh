#!/bin/bash

# Dauer (in Sekunden), wie lange der Autoscroll ausgeführt wird
DURATION=1000009  # Passe diesen Wert nach Belieben an

# Scroll-Intervall (kleineres Intervall für smoothere Scrolling)
INTERVAL=0.4  # 0.05 Sekunden Pause zwischen den Scrolls

# Anzahl der Scroll-Schritte pro Sekunde
STEPS_PER_SECOND=20  # Erhöhe diesen Wert für smootheres Scrollen

# Startzeit
START_TIME=$(date +%s)

# Loop für die angegebene Dauer
while [ $(($(date +%s) - START_TIME)) -lt $DURATION ]; do
    # Scrollen nach oben (4 bedeutet Scrollrad nach oben)
    for ((i = 0; i < $STEPS_PER_SECOND; i++)); do
        xdotool click 4  # Nach oben scrollen
        sleep $INTERVAL
    done
done
