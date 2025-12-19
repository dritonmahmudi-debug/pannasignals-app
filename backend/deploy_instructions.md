# Udhëzues për Deployment në VPS

## 1. Përgatitja e VPS

### Hapi 1: Lidhu me VPS
```bash
ssh root@ip_e_vps_tuaj
```

### Hapi 2: Update sistemi
```bash
apt update && apt upgrade -y
```

### Hapi 3: Instalo Python dhe dependencat
```bash
apt install python3 python3-pip python3-venv -y
```

## 2. Upload i Projektit

### Metoda 1: Me SCP (nga kompjuteri lokal)
```bash
scp -r c:\Users\DELL\Desktop\signals_app\backend root@ip_e_vps:/var/www/signals_backend
```

### Metoda 2: Me Git (e rekomanduar)
```bash
# Në VPS
mkdir -p /var/www/signals_backend
cd /var/www/signals_backend
git clone url_e_projektit_tuaj .
```

## 3. Konfiguro Python Environment

```bash
cd /var/www/signals_backend

# Krijo virtual environment
python3 -m venv venv

# Aktivizo
source venv/bin/activate

# Instalo dependencat
pip install -r requirements.txt
```

## 4. Konfiguro si Systemd Service (24/7)

Krijo file: `/etc/systemd/system/signals-api.service`

```ini
[Unit]
Description=Signals API Backend
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/var/www/signals_backend
Environment="PATH=/var/www/signals_backend/venv/bin"
ExecStart=/var/www/signals_backend/venv/bin/uvicorn main_full:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

## 5. Aktivizo dhe Starto Service

```bash
# Reload systemd
systemctl daemon-reload

# Aktivizo që të starton automatikisht
systemctl enable signals-api

# Starto service
systemctl start signals-api

# Shiko statusin
systemctl status signals-api
```

## 6. Komandat Kryesore

```bash
# Starto service
systemctl start signals-api

# Ndalo service
systemctl stop signals-api

# Restarto service
systemctl restart signals-api

# Shiko logs
journalctl -u signals-api -f

# Shiko statusin
systemctl status signals-api
```

## 7. Konfiguro Firewall

```bash
# Lejo portin 8000
ufw allow 8000

# Ose për HTTPS
ufw allow 443
ufw allow 80
```

## 8. (Opsional) Konfiguro Nginx si Reverse Proxy

### Instalo Nginx
```bash
apt install nginx -y
```

### Krijo konfigurimin: `/etc/nginx/sites-available/signals`
```nginx
server {
    listen 80;
    server_name domain_yt.com;  # Ndrysho me domain-in tënd

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### Aktivizo konfigurimin
```bash
ln -s /etc/nginx/sites-available/signals /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
```

## 9. (Opsional) SSL me Let's Encrypt

```bash
apt install certbot python3-certbot-nginx -y
certbot --nginx -d domain_yt.com
```

## 10. Monitorimi

```bash
# Shiko CPU dhe RAM
htop

# Shiko logs në real-time
journalctl -u signals-api -f

# Shiko sa kohë ka punuar
systemctl status signals-api
```

## Troubleshooting

### Nëse service nuk starton:
```bash
journalctl -u signals-api -n 50
```

### Nëse duhet të ndryshosh kod:
```bash
cd /var/www/signals_backend
git pull  # ose ndrysho file-at manualisht
systemctl restart signals-api
```

### Test nëse punon:
```bash
curl http://localhost:8000
# ose
curl http://ip_e_vps:8000
```
