#!/bin/bash
# Script de preparación para las sesiones de Claude Code en la nube (claude.ai/code).
# Se pega en el entorno de la nube (Setup script): instala Godot sin ventana en Linux.
# Las descargas de GitHub están en la lista de dominios permitidos del nivel «Trusted».
set -e
V=4.7.2-stable
cd /opt
curl -sSL -o godot.zip "https://github.com/godotengine/godot/releases/download/${V}/Godot_v${V}_linux.x86_64.zip"
unzip -o -q godot.zip && rm godot.zip
ln -sf "/opt/Godot_v${V}_linux.x86_64" /usr/local/bin/godot
pip install --quiet pillow requests || true  # para tools/build_map.py
godot --version
