#!/usr/bin/env bash
# Setup-Skript für lokales Testen ohne GitHub-Zugriff
# Dieses Skript kopiert die notwendigen Dateien auf den Proxmox Host

echo "=========================================="
echo "Lokales Test-Setup für n8n-install.sh"
echo "=========================================="
echo ""
echo "Dieses Skript hilft dir, die Test-Dateien auf deinen Proxmox Host zu kopieren."
echo ""
read -p "Proxmox Host IP oder Hostname: " PVE_HOST
read -p "SSH Benutzer (normalerweise 'root'): " SSH_USER
SSH_USER=${SSH_USER:-root}

echo ""
echo "Kopiere Dateien auf $SSH_USER@$PVE_HOST..."

# Erstelle temporäres Verzeichnis auf dem Host
ssh $SSH_USER@$PVE_HOST "mkdir -p /tmp/proxmoxve-test"

# Kopiere die geänderten Dateien
echo "Kopiere install/n8n-install.sh..."
scp install/n8n-install.sh $SSH_USER@$PVE_HOST:/tmp/proxmoxve-test/n8n-install.sh

echo "Kopiere misc/build.func..."
scp misc/build.func $SSH_USER@$PVE_HOST:/tmp/proxmoxve-test/build.func

echo "Kopiere ct/n8n-test.sh..."
scp ct/n8n-test.sh $SSH_USER@$PVE_HOST:/tmp/proxmoxve-test/n8n-test.sh

echo ""
echo "=========================================="
echo "Setup abgeschlossen!"
echo "=========================================="
echo ""
echo "Auf deinem Proxmox Host kannst du jetzt folgendes ausführen:"
echo ""
echo "1. Erstelle ein lokales Verzeichnis:"
echo "   mkdir -p /opt/proxmoxve-test"
echo "   cp /tmp/proxmoxve-test/* /opt/proxmoxve-test/"
echo ""
echo "2. Führe das Test-Skript aus:"
echo "   bash /opt/proxmoxve-test/n8n-test-local.sh"
echo ""
echo "ODER verwende die manuelle Methode (siehe TEST-LOCAL.md)"

