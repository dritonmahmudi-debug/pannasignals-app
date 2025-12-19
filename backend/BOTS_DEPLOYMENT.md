# Udhëzues për Upload dhe Konfigurimin e Botave

## Hapi 1: Upload Bots në VPS

Nga **PowerShell lokal**, ekzekuto:

```powershell
# Upload të gjitha file-at e botave
scp -r C:\Users\DELL\Desktop\signals_bots\* root@194.163.165.198:/var/www/signals_backend/bots/
```

## Hapi 2: Krijo Folder në VPS dhe Kontrollo

Në **SSH terminal**:

```bash
# Krijo folder për bots
mkdir -p /var/www/signals_backend/bots
cd /var/www/signals_backend/bots

# Shiko file-at
ls -la
```

## Hapi 3: Instalo Dependencat

Në **SSH terminal**:

```bash
cd /var/www/signals_backend
source venv/bin/activate

# Instalo library të nevojshme
pip install pandas numpy yfinance requests python-dotenv

# Deaktivizo
deactivate
```

## Hapi 4: Krijo Systemd Services për Çdo Bot

### Bot 1: Forex Swing Bot

```bash
nano /etc/systemd/system/forex-swing-bot.service
```

Kopjo këtë:

```ini
[Unit]
Description=Forex Swing Trading Bot
After=network.target signals-api.service

[Service]
Type=simple
User=root
WorkingDirectory=/var/www/signals_backend/bots
Environment="PATH=/var/www/signals_backend/venv/bin"
ExecStart=/var/www/signals_backend/venv/bin/python3 forex_swing_bot.py
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
```

### Bot 2: Forex Scalp Bot

```bash
nano /etc/systemd/system/forex-scalp-bot.service
```

```ini
[Unit]
Description=Forex Scalping Trading Bot
After=network.target signals-api.service

[Service]
Type=simple
User=root
WorkingDirectory=/var/www/signals_backend/bots
Environment="PATH=/var/www/signals_backend/venv/bin"
ExecStart=/var/www/signals_backend/venv/bin/python3 forex_scalp_bot.py
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
```

### Bot 3: Crypto Swing Bot

```bash
nano /etc/systemd/system/crypto-swing-bot.service
```

```ini
[Unit]
Description=Crypto Swing Trading Bot
After=network.target signals-api.service

[Service]
Type=simple
User=root
WorkingDirectory=/var/www/signals_backend/bots
Environment="PATH=/var/www/signals_backend/venv/bin"
ExecStart=/var/www/signals_backend/venv/bin/python3 crypto_swing_bot.py
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
```

### Bot 4: Crypto Scalp Bot

```bash
nano /etc/systemd/system/crypto-scalp-bot.service
```

```ini
[Unit]
Description=Crypto Scalping Trading Bot
After=network.target signals-api.service

[Service]
Type=simple
User=root
WorkingDirectory=/var/www/signals_backend/bots
Environment="PATH=/var/www/signals_backend/venv/bin"
ExecStart=/var/www/signals_backend/venv/bin/python3 crypto_scalp_bot.py
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
```

## Hapi 5: Aktivizo dhe Starto të Gjithë Botat

```bash
# Reload systemd
systemctl daemon-reload

# Aktivizo të gjithë
systemctl enable forex-swing-bot
systemctl enable forex-scalp-bot
systemctl enable crypto-swing-bot
systemctl enable crypto-scalp-bot

# Starto të gjithë
systemctl start forex-swing-bot
systemctl start forex-scalp-bot
systemctl start crypto-swing-bot
systemctl start crypto-scalp-bot

# Shiko statusin
systemctl status forex-swing-bot
systemctl status forex-scalp-bot
systemctl status crypto-swing-bot
systemctl status crypto-scalp-bot
```

## Hapi 6: Monitorimi

```bash
# Shiko logs për një bot specifik
journalctl -u forex-swing-bot -f

# Shiko logs për të gjithë botat
journalctl -f | grep -E "(forex|crypto).*bot"

# Shiko statusin e të gjithëve
systemctl status forex-swing-bot forex-scalp-bot crypto-swing-bot crypto-scalp-bot
```

## Komandat e Dobishme

```bash
# Restarto një bot
systemctl restart forex-swing-bot

# Ndalo një bot
systemctl stop forex-swing-bot

# Shiko logs e fundit
journalctl -u forex-swing-bot -n 50

# Restarto të gjithë botat
systemctl restart forex-swing-bot forex-scalp-bot crypto-swing-bot crypto-scalp-bot
```

## Troubleshooting

### Nëse bot nuk starton:
```bash
journalctl -u forex-swing-bot -n 100
```

### Testo bot manualisht:
```bash
cd /var/www/signals_backend/bots
source ../venv/bin/activate
python3 forex_swing_bot.py
```

### Kontrollo nëse API është duke punuar:
```bash
curl http://localhost:8000/signals | head -20
```
