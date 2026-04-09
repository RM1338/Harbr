"""
================================================================
  SMART PARKING SYSTEM — Python Middleware
  Listens to MQTT → writes to Firebase + InfluxDB
================================================================

SETUP (run these once):
  pip install paho-mqtt firebase-admin influxdb-client

MQTT topics subscribed:
  parking/slots   → { "slot": 1, "status": 0|1 }
  parking/counts  → { "entries": N }
"""

import json
import paho.mqtt.client as mqtt
from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS
import firebase_admin
from firebase_admin import credentials, db

# ── CONFIG — Fill these in ───────────────────────────────────────
MQTT_BROKER     = "localhost"
MQTT_PORT       = 1883

INFLUX_URL      = "https://us-east-1-1.aws.cloud2.influxdata.com"
INFLUX_TOKEN    = "YOUR_INFLUX_TOKEN"
INFLUX_ORG      = "YOUR_ORG"
INFLUX_BUCKET   = "parking"

FIREBASE_CRED   = "serviceAccountKey.json"   # Download from Firebase console
FIREBASE_DB_URL = "https://YOUR-PROJECT.firebaseio.com"
# ─────────────────────────────────────────────────────────────────

# Status map for human-readable Firebase values
STATUS_MAP = {0: "free", 1: "occupied", 2: "reserved"}

# ── InfluxDB setup ───────────────────────────────────────────────
influx_client = InfluxDBClient(url=INFLUX_URL, token=INFLUX_TOKEN, org=INFLUX_ORG)
write_api = influx_client.write_api(write_options=SYNCHRONOUS)

# ── Firebase setup ───────────────────────────────────────────────
cred = credentials.Certificate(FIREBASE_CRED)
firebase_admin.initialize_app(cred, {"databaseURL": FIREBASE_DB_URL})


# ================================================================
#  WRITERS
# ================================================================

def write_slot_to_influx(slot: int, status: int):
    point = (
        Point("parking_slots")
        .tag("slot", f"A0{slot}")
        .field("status", status)
    )
    write_api.write(bucket=INFLUX_BUCKET, record=point)
    print(f"[InfluxDB] slot A0{slot} → status {status}")


def write_slot_to_firebase(slot: int, status: int):
    slot_id = f"A0{slot}"
    status_str = STATUS_MAP.get(status, "unknown")
    db.reference(f"/slots/{slot_id}").set({
        "status": status_str,
        "raw": status
    })
    print(f"[Firebase] /slots/{slot_id} → {status_str}")


def write_count_to_firebase(entries: int):
    db.reference("/counts").update({"entries": entries})
    print(f"[Firebase] /counts/entries → {entries}")


def write_count_to_influx(entries: int):
    point = (
        Point("parking_counts")
        .field("entries", entries)
    )
    write_api.write(bucket=INFLUX_BUCKET, record=point)
    print(f"[InfluxDB] entries → {entries}")


# ================================================================
#  MQTT CALLBACKS
# ================================================================

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("✓ Connected to MQTT broker")
        client.subscribe("parking/slots")
        client.subscribe("parking/counts")
    else:
        print(f"✗ MQTT connection failed, code: {rc}")


def on_message(client, userdata, msg):
    topic = msg.topic
    try:
        data = json.loads(msg.payload.decode())
        print(f"\n[MQTT] {topic}: {data}")

        if topic == "parking/slots":
            slot   = data.get("slot", 1)
            status = data.get("status", 0)
            write_slot_to_influx(slot, status)
            write_slot_to_firebase(slot, status)

        elif topic == "parking/counts":
            entries = data.get("entries", 0)
            write_count_to_influx(entries)
            write_count_to_firebase(entries)

    except (json.JSONDecodeError, KeyError) as e:
        print(f"[ERROR] Bad message on {topic}: {e}")


# ================================================================
#  MAIN
# ================================================================

if __name__ == "__main__":
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message

    print(f"Connecting to MQTT at {MQTT_BROKER}:{MQTT_PORT} ...")
    client.connect(MQTT_BROKER, MQTT_PORT)
    client.loop_forever()
