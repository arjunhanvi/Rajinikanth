#!/bin/bash
# Runs an automated play-test scenario under a virtual display. Usage: tools/playtest.sh <scenario> [extra args]
cd "$(dirname "$0")/.."
sc="$1"; shift
extra=""; [ "$sc" != "story" ] && extra="--free"   # everything except the story test runs in free roam
timeout ${PT_TIMEOUT:-240} xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -- --play --auto --harness=$sc $extra "$@" 2>&1 | grep -vE "ALSA|audio_driver|All audio drivers|servers/audio|V-Sync|gl_manager|^$|Godot Engine|OpenGL API"
