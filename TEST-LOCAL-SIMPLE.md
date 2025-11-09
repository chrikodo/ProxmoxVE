# Einfache lokale Testmethode (ohne GitHub-Zugriff)

Diese Methode testet nur das `install/n8n-install.sh` Skript direkt im Container, ohne die komplexe `build.func` zu verwenden.

## Schritt 1: Kopiere das geänderte Skript auf den Proxmox Host

```bash
# Von deinem Mac aus:
scp install/n8n-install.sh root@<DEIN_PVE_HOST_IP>:/tmp/n8n-install.sh
```

## Schritt 2: Erstelle einen Test-Container (Debian 13)

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

## Schritt 3: Starte den Container und kopiere das Skript

```bash
# Starte den Container
pct start 999

# Warte kurz, bis der Container läuft
sleep 5

# Kopiere das geänderte Installationsskript in den Container
pct push 999 /tmp/n8n-install.sh /root/n8n-install.sh
```

## Schritt 4: Lade die Funktionen-Datei (von GitHub, aber nur einmal)

```bash
# Lade die Funktionen-Datei (benötigt Internet im Container)
FUNCTIONS_FILE_PATH=$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/install.func)

# Falls der Container kein Internet hat, kopiere die Datei lokal:
# 1. Lade install.func auf deinen Mac:
#    curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/install.func > /tmp/install.func
# 2. Kopiere auf den Proxmox Host:
#    scp /tmp/install.func root@<PVE_HOST>:/tmp/install.func
# 3. Kopiere in den Container:
#    pct push 999 /tmp/install.func /tmp/install.func
# 4. Lade lokal:
#    FUNCTIONS_FILE_PATH=$(cat /tmp/install.func)
```

## Schritt 5: Führe das Installationsskript aus

```bash
# Führe das Skript im Container aus
pct exec 999 -- bash -c "export FUNCTIONS_FILE_PATH='$FUNCTIONS_FILE_PATH' && bash /root/n8n-install.sh"
```

## Schritt 6: Überprüfe das Ergebnis

```bash
# Prüfe ob python3-setuptools installiert wurde
pct exec 999 -- dpkg -l | grep python3-setuptools

# Prüfe ob n8n installiert wurde
pct exec 999 -- npm list -g n8n

# Prüfe ob der Service läuft
pct exec 999 -- systemctl status n8n
```

## Schritt 7: Teste die sqlite3 Kompilierung

```bash
# Teste ob sqlite3 ohne distutils-Fehler kompiliert
pct exec 999 -- bash -c "npm install sqlite3 --global 2>&1 | grep -i 'distutils\|error' || echo 'OK: Keine distutils Fehler'"
```

## Aufräumen

Nach dem Test kannst du den Container löschen:

```bash
pct stop 999
pct destroy 999
```

## Falls der Container kein Internet hat

Wenn der Container kein Internet hat, musst du die Funktionen-Datei lokal bereitstellen:

1. **Lade install.func auf deinen Mac:**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/install.func > /tmp/install.func
   ```

2. **Kopiere auf den Proxmox Host:**
   ```bash
   scp /tmp/install.func root@<PVE_HOST>:/tmp/install.func
   ```

3. **Kopiere in den Container:**
   ```bash
   pct push 999 /tmp/install.func /tmp/install.func
   ```

4. **Führe das Skript mit lokaler Funktionen-Datei aus:**
   ```bash
   FUNCTIONS_FILE_PATH=$(cat /tmp/install.func)
   pct exec 999 -- bash -c "export FUNCTIONS_FILE_PATH='$FUNCTIONS_FILE_PATH' && bash /root/n8n-install.sh"
   ```

