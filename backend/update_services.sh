#!/bin/bash

# Update all bot services to use unbuffered Python output

for service in crypto-swing-bot crypto-scalp-bot forex-swing-bot forex-scalp-bot; do
    sed -i '/Environment="PATH/a Environment="PYTHONUNBUFFERED=1"' /etc/systemd/system/${service}.service
done

systemctl daemon-reload
systemctl restart crypto-swing-bot crypto-scalp-bot forex-swing-bot forex-scalp-bot

echo "✅ All services updated and restarted with unbuffered output"
