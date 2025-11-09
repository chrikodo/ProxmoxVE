# Lokales Testen von n8n-install.sh

Diese Anleitung zeigt dir, wie du das geänderte `install/n8n-install.sh` Skript lokal auf deinem Proxmox VE Host testest, bevor du den Pull Request erstellst.

## Voraussetzungen

- SSH-Zugriff auf deinen Proxmox VE Host (als root)
- Ein Debian 13 Template auf deinem Proxmox Host
- Das geänderte `install/n8n-install.sh` Skript in deinem lokalen Repository

## Methode 1: Manuelles Testen im Container (Empfohlen)

### Schritt 1: Kopiere das geänderte Skript auf den Proxmox Host

```bash
# Von deinem Mac aus:
scp install/n8n-install.sh root@<DEIN_PVE_HOST_IP>:/tmp/n8n-install.sh
```

### Schritt 2: Erstelle einen Test-Container (Debian 13)

```bash
# SSH auf deinen Proxmox Host:
ssh root@<DEIN_PVE_HOST_IP>

# Erstelle einen Test-Container (ID 999, anpassbar)
pct create 999 \
  local:vztmpl/debian-13-standard_*.tar.zst \
  --hostname n8n-test \
  --storage local-lvm \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --memory 2048 \
  --cores 2 \
  --unprivileged 1 \
  --onboot 0
```

**Hinweis:** Passe die Container-ID (999), den Storage-Namen (`local-lvm`) und das Template an deine Umgebung an.

### Schritt 3: Starte den Container und kopiere das Skript

```bash
# Starte den Container
pct start 999

# Warte kurz, bis der Container läuft
sleep 5

# Kopiere das geänderte Installationsskript in den Container
pct push 999 /tmp/n8n-install.sh /root/n8n-install.sh
```

### Schritt 4: Bereite den Container vor (Funktionen laden)

Das Installationsskript benötigt die Funktionen-Datei. Lade sie zuerst:

```bash
# Lade die Funktionen-Datei
FUNCTIONS_FILE_PATH=$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/install.func)
pct exec 999 -- bash -c "export FUNCTIONS_FILE_PATH='$FUNCTIONS_FILE_PATH' && bash /root/n8n-install.sh"
```

### Schritt 5: Überprüfe das Ergebnis

Nach der Installation solltest du prüfen, ob:

1. `python3-setuptools` installiert wurde:
```bash
pct exec 999 -- dpkg -l | grep python3-setuptools
```

2. n8n erfolgreich installiert wurde:
```bash
pct exec 999 -- npm list -g n8n
```

3. Der n8n Service läuft:
```bash
pct exec 999 -- systemctl status n8n
```

### Schritt 6: Teste die sqlite3 Kompilierung

Um sicherzustellen, dass der Bug behoben ist, teste die sqlite3 Installation:

```bash
pct exec 999 -- bash -c "npm install sqlite3 --global 2>&1 | grep -i 'distutils\|error' || echo 'OK: Keine distutils Fehler'"
```

### Aufräumen

Nach dem Test kannst du den Container löschen:

```bash
pct stop 999
pct destroy 999
```

## Methode 2: Temporäre Modifikation von build.func

Alternativ kannst du `build.func` temporär modifizieren, um das lokale Skript zu verwenden:

1. Kopiere `install/n8n-install.sh` auf den Proxmox Host nach `/root/n8n-install.sh`
2. Modifiziere Zeile 1345 in `build.func` temporär:
   ```bash
   # Original:
   lxc-attach -n "$CTID" -- bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/${var_install}.sh)"
   
   # Für n8n Test:
   if [ "$var_install" == "n8n-install" ]; then
     lxc-attach -n "$CTID" -- bash -c "$(cat /root/n8n-install.sh)"
   else
     lxc-attach -n "$CTID" -- bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/${var_install}.sh)"
   fi
   ```
3. Führe dann `ct/n8n.sh` normal aus

**Warnung:** Diese Methode erfordert, dass du `build.func` lokal auf dem Proxmox Host modifizierst.

## Was zu testen ist

- ✅ `python3-setuptools` wird installiert
- ✅ `npm install -g n8n` schlägt nicht mit `ModuleNotFoundError: No module named 'distutils'` fehl
- ✅ n8n Service startet erfolgreich
- ✅ n8n ist über HTTP erreichbar (Port 5678)

## Troubleshooting

Falls Probleme auftreten:

1. **Container startet nicht:** Prüfe die Container-Logs mit `pct status 999`
2. **Netzwerk-Probleme:** Stelle sicher, dass der Container eine IP-Adresse hat: `pct exec 999 -- ip a`
3. **Skript-Fehler:** Führe das Skript mit `bash -x` aus, um Debug-Output zu sehen:
   ```bash
   pct exec 999 -- bash -x /root/n8n-install.sh
   ```

