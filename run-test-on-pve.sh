#!/usr/bin/env bash
# Test-Skript für Proxmox Host (192.168.180.5)
# Führt n8n-install.sh im Test-Container aus

CTID=999
HOST_IP="192.168.180.5"

echo "=========================================="
echo "n8n Installations-Test"
echo "=========================================="
echo ""

# Prüfe ob Container bereits existiert
if pct list | grep -q "^$CTID "; then
  echo "Container $CTID existiert bereits."
  read -p "Löschen und neu erstellen? (j/n): " answer
  if [[ "$answer" == "j" || "$answer" == "J" ]]; then
    echo "Stoppe und lösche Container $CTID..."
    pct stop $CTID 2>/dev/null
    pct destroy $CTID
  else
    echo "Verwende existierenden Container."
    pct start $CTID 2>/dev/null
    sleep 3
  fi
fi

# Erstelle Container falls nicht vorhanden
if ! pct list | grep -q "^$CTID "; then
  echo "Erstelle Test-Container $CTID (Debian 13)..."
  
  # Finde verfügbares Template
  TEMPLATE=$(ls /var/lib/vz/template/cache/debian-13-standard_*.tar.zst 2>/dev/null | head -1)
  
  if [ -z "$TEMPLATE" ]; then
    echo "Fehler: Kein Debian 13 Template gefunden!"
    echo "Bitte lade zuerst ein Template herunter:"
    echo "  pveam download local debian-13-standard"
    exit 1
  fi
  
  echo "Verwende Template: $TEMPLATE"
  
  pct create $CTID \
    $TEMPLATE \
    --hostname n8n-test \
    --storage local-lvm \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp \
    --memory 2048 \
    --cores 2 \
    --unprivileged 1 \
    --onboot 0
  
  if [ $? -ne 0 ]; then
    echo "Fehler beim Erstellen des Containers!"
    exit 1
  fi
  
  echo "Container erstellt."
fi

# Starte Container
echo "Starte Container $CTID..."
pct start $CTID

# Warte bis Container läuft
echo "Warte auf Container..."
for i in {1..10}; do
  if pct status $CTID | grep -q "status: running"; then
    echo "Container läuft."
    break
  fi
  sleep 1
  if [ $i -eq 10 ]; then
    echo "Fehler: Container startet nicht!"
    exit 1
  fi
done

sleep 3

# Kopiere Dateien in Container
echo "Kopiere Dateien in Container..."
pct push $CTID /tmp/n8n-install.sh /root/n8n-install.sh
pct push $CTID /tmp/install.func /tmp/install.func

# Lade Funktionen und führe Skript aus
echo ""
echo "=========================================="
echo "Führe Installationsskript aus..."
echo "=========================================="
echo ""

FUNCTIONS_FILE_PATH=$(cat /tmp/install.func)
pct exec $CTID -- bash -c "export FUNCTIONS_FILE_PATH='$FUNCTIONS_FILE_PATH' && bash /root/n8n-install.sh"

if [ $? -eq 0 ]; then
  echo ""
  echo "=========================================="
  echo "Installation abgeschlossen!"
  echo "=========================================="
  echo ""
  echo "Überprüfe Installation:"
  echo ""
  echo "1. Prüfe python3-setuptools:"
  pct exec $CTID -- dpkg -l | grep python3-setuptools
  echo ""
  echo "2. Prüfe n8n Installation:"
  pct exec $CTID -- npm list -g n8n 2>/dev/null | head -3
  echo ""
  echo "3. Prüfe n8n Service:"
  pct exec $CTID -- systemctl status n8n --no-pager | head -5
  echo ""
  echo "4. Teste sqlite3 Kompilierung:"
  pct exec $CTID -- bash -c "npm install sqlite3 --global 2>&1 | grep -i 'distutils\|error' || echo '✓ OK: Keine distutils Fehler'"
  echo ""
  IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')
  echo "n8n sollte erreichbar sein unter: http://$IP:5678"
else
  echo ""
  echo "=========================================="
  echo "Fehler bei der Installation!"
  echo "=========================================="
  echo ""
  echo "Prüfe die Logs:"
  echo "  pct exec $CTID -- journalctl -u n8n -n 20"
fi

