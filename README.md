# Alerte autonomie *UPS* (NUT) avec notification Discord

⏱️ **Objectif**  
Surveiller l’**autonomie restante** (*battery.runtime* en secondes) d’un **UPS** exposé par **NUT** (`upsc`).  
- Si l’autonomie **< 300 s**, envoie **une alerte Discord** (une seule fois tant que la condition persiste), logue l’événement, puis **désactive** les alertes suivantes via un **fichier d’état**.  
- Quand l’autonomie remonte **≥ 300 s**, le fichier d’état est **réinitialisé** afin de pouvoir renvoyer une future alerte si ça rechute.

---

## 🧩 Fonctionnement (résumé)
1. Récupère les métriques via :  
   ```bash
   upsc eaton@localhost
   ```
   Les champs utilisés sont : `ups.status`, `battery.runtime`, `battery.charge`, `device.model`.
2. Si `battery.runtime < 300` :  
   - Si **aucun envoi précédent** (fichier `/tmp/ups-runtime-alert.sent` **absent**) → **envoi** d’un message **Discord** + **journalisation** dans `/var/log/ups-shutdown.log`, puis **création** du fichier d’état.  
   - Si le fichier d’état **existe**, **aucune alerte** supplémentaire n’est envoyée (anti-spam).  
3. Si `battery.runtime ≥ 300` :  
   - **Suppression** du fichier d’état (reset), ce qui réautorise une alerte lors d’une future baisse.

---

## ✅ Prérequis
- **NUT** (Network UPS Tools) installé et configuré (service `upsd` + `upsc` fonctionnel).
- Un **UPS** déclaré et accessible sous le nom **`eaton@localhost`** (adapter si besoin).  
  Test rapide :  
  ```bash
  upsc eaton@localhost | head -n 20
  ```
- Accès **HTTP sortant** vers l’URL **Discord Webhook**.
- **`jq`** pour sérialiser le JSON. (Le script présuppose `jq` présent.)

---

## 🔧 Variables (dans le script)
| Variable     | Par défaut                               | Description |
|--------------|-------------------------------------------|-------------|
| `WEBHOOK`    | `https://discord.com/api/webhooks/...`    | URL du **Discord Webhook** (remplacer par la vôtre). |
| `LOGFILE`    | `/var/log/ups-shutdown.log`               | Fichier **log** des alertes envoyées. |
| `STATEFILE`  | `/tmp/ups-runtime-alert.sent`             | **Flag** pour éviter les alertes répétées tant que la condition persiste. |

> ℹ️ Le **seuil** est **fixe** à **300 secondes** dans ce script. Adaptez la ligne `if [[ "$RUNTIME" -lt 300 ]]; then` pour modifier la valeur.

---

## 📦 Installation
1. Copier le script :  
   ```bash
   install -m 0755 check-ups-runtime.sh /home/scripts/check-ups-runtime.sh
   ```
2. Éditer la variable `WEBHOOK` avec votre URL.  
3. Créer le répertoire de log si besoin :  
   ```bash
   touch /var/log/ups-shutdown.log
   ```

> 💡 Votre organisation utilise `/home/scripts` comme dossier de référence.

---

## ▶️ Utilisation manuelle
```bash
/home/scripts/check-ups-runtime.sh
```
- Si `upsc` renvoie une autonomie `< 300`, une alerte est envoyée **une seule fois** (puisque `STATEFILE` est créé).  
- Quand l’autonomie repasse au-dessus, l’alerte est **réarmable**.

---

## ⏱️ Planification (cron)
Exemple : **toutes les minutes** (recommandé pour une alerte quasi temps réel) :  
```cron
* * * * * /home/scripts/check-ups-runtime.sh
```
- Le système de **flag** (`STATEFILE`) empêche l’**inondation d’alertes**.  
- Redirigez vers un log si vous souhaitez historiser l’exécution :  
  ```cron
  * * * * * /home/scripts/check-ups-runtime.sh >> /var/log/check-ups-runtime.cron.log 2>&1
  ```

---

## 🔔 Format de la notification Discord
Message court, compatible avec la **limite 2000 caractères** :  
```
⏱ <hostname> — ⚠️ Autonomie critique UPS à <date>
🔋 Batterie : <battery.charge> %
⏳ Autonomie : <battery.runtime> sec
🖥️ Modèle : <device.model>
```
- Envoi via `jq -n --arg content` puis `curl -H "Content-Type: application/json"`.

---

## 🧪 Vérifications & tests
1. **NUT en place** :  
   ```bash
   systemctl status nut-server nut-monitor 2>/dev/null || true
   upsc eaton@localhost | egrep 'ups.status|battery.runtime|battery.charge|device.model'
   ```
2. **Alerte unique** :  
   - Simulez un **runtime bas** (test réel en débranchant le secteur est **à vos risques**).  
   - Lancez le script plusieurs fois : une **seule alerte** doit partir tant que `STATEFILE` existe.  
3. **Reset** :  
   - Quand `battery.runtime` remonte ≥ 300, vérifiez la **suppression** de `STATEFILE`.

> ⚠️ Évitez de débrancher le secteur sur un système de production sans procédure d’exploitation validée.

---

## 🧰 Dépannage
- **Aucune sortie `upsc`** :  
  - Vérifier la **config NUT**, le nom d’UPS (`eaton@localhost`), les droits d’accès.  
- **Pas d’alerte Discord** :  
  - Vérifier `WEBHOOK`, DNS/réseau sortant, et consulter `LOGFILE`.  
- **Alerte non réarmable** :  
  - Supprimer manuellement le flag : `rm -f /tmp/ups-runtime-alert.sent`.

---

## 🔒 Sécurité & impacts
- Lecture seule des métriques **NUT** (aucune action de shutdown).  
- La **fréquence cron** et le **seuil** doivent refléter vos contraintes d’exploitation.  
- Le log `/var/log/ups-shutdown.log` peut contenir des horodatages d’événements sensibles : gérez les accès.

---

## ✨ Améliorations suggérées (optionnelles)
- Rendre le **seuil configurable** via variable d’environnement (ex. `RUNTIME_THRESHOLD`, défaut 300).  
- Ajouter un **cooldown** chronométré (ex. ne pas renvoyer plus d’une alerte toutes les X minutes même après reset).  
- Ajouter l’**état secteur** (`input.voltage`, `ups.load`, etc.) dans le message.  
- Joindre le **journal** en pièce jointe (méthode `curl -F`) si vous souhaitez conserver le log côté Discord.

---

## 🗑️ Désinstallation
```bash
crontab -e   # retirer l'entrée si ajoutée
rm -f /home/scripts/check-ups-runtime.sh /tmp/ups-runtime-alert.sent /var/log/check-ups-runtime.log
```

---

## 📄 Licence
Utilisation interne. Adapter selon votre politique de sécurité.
