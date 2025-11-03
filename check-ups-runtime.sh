#!/bin/bash

WEBHOOK="https://discord.com/api/webhooks/1234567890987654321/jsdkghfojahjgoaropihjgoirhjfsdighajsdfnbgkvjasznbfgousoghsoaghoasdhgjnsdfjnv;jsdfnvjfsdgnd"
LOGFILE="/var/log/ups-shutdown.log"
STATEFILE="/tmp/ups-runtime-alert.sent"

UPS_DATA=$(upsc eaton@localhost 2>/dev/null)
STATUS=$(echo "$UPS_DATA" | awk -F': ' '/^ups.status:/ {print $2}')
RUNTIME=$(echo "$UPS_DATA" | awk -F': ' '/^battery.runtime:/ {print $2}')
BATTERY_CHARGE=$(echo "$UPS_DATA" | awk -F': ' '/^battery.charge:/ {print $2}')
MODEL=$(echo "$UPS_DATA" | awk -F': ' '/^device.model:/ {print $2}')

# Si autonomie < 300 sec et que message pas encore envoyé
if [[ "$RUNTIME" -lt 300 ]]; then
  if [[ ! -f "$STATEFILE" ]]; then
    MESSAGE="⏱ *$(hostname)* — ⚠️ Autonomie critique UPS à $(date '+%F %T')\n🔋 Batterie : ${BATTERY_CHARGE} %\n⏳ Autonomie : ${RUNTIME} sec\n🖥️ Modèle : ${MODEL}"
    echo "$(date '+%F %T') 🚨 ALERTE: autonomie < 300 sec (batt=$BATTERY_CHARGE%, runtime=$RUNTIME sec)" >> "$LOGFILE"
    jq -n --arg content "$MESSAGE" '{content: $content}' | \
      curl -s -H "Content-Type: application/json" -X POST -d @- "$WEBHOOK" > /dev/null
    touch "$STATEFILE"
  fi
else
  # Si autonomie > 300 sec, reset le flag d’alerte
  [[ -f "$STATEFILE" ]] && rm -f "$STATEFILE"
fi
