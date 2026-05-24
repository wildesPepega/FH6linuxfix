#!/bin/bash
# FH6 VKD3D Shader Cache Warmup
# Run this before playing to check cache status and optionally back it up.

if [ "$EUID" -eq 0 ]; then
    echo "Do not run this script with sudo. Run it as your normal user."
    exit 1
fi

CACHE_DIR="$HOME/.local/share/Steam/steamapps/shadercache/2483190/VKD3D_shader_cache"
CACHE_FILE="$CACHE_DIR/vkd3d-proton.forzahorizon6.exe.cache"
BACKUP_DIR="$HOME/.local/share/fh6-shader-backup"

echo "=== FH6 VKD3D Shader Cache ==="
if [ -f "$CACHE_FILE" ]; then
    SIZE=$(du -sh "$CACHE_FILE" | cut -f1)
    MODIFIED=$(stat -c '%y' "$CACHE_FILE" | cut -d'.' -f1)
    echo "Cache size:     $SIZE"
    echo "Last modified:  $MODIFIED"
else
    echo "No cache found at $CACHE_FILE"
fi

echo ""
echo "Options:"
echo "  1) Backup current cache"
echo "  2) Restore last backup"
echo "  3) Exit"
read -p "Choice: " choice

case $choice in
    1)
        mkdir -p "$BACKUP_DIR"
        cp "$CACHE_FILE" "$BACKUP_DIR/vkd3d-cache-$(date +%Y%m%d-%H%M%S).bak"
        echo "Backed up to $BACKUP_DIR"
        ;;
    2)
        LATEST=$(ls -t "$BACKUP_DIR"/*.bak 2>/dev/null | head -1)
        if [ -z "$LATEST" ]; then
            echo "No backup found."
        else
            cp "$LATEST" "$CACHE_FILE"
            echo "Restored: $LATEST"
            echo "Cache size: $(du -sh "$CACHE_FILE" | cut -f1)"
        fi
        ;;
    *)
        exit 0
        ;;
esac
