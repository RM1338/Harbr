"""
conftest.py — Stub out heavy third-party dependencies before any cv_pipeline
module is imported, so tests can run without firebase_admin or influxdb_client.
"""
import sys
from unittest.mock import MagicMock

# Stub firebase_admin and its sub-modules
_firebase_admin = MagicMock()
sys.modules.setdefault("firebase_admin", _firebase_admin)
sys.modules.setdefault("firebase_admin.credentials", _firebase_admin.credentials)
sys.modules.setdefault("firebase_admin.db", _firebase_admin.db)

# Stub influxdb_client and its sub-modules
_influx = MagicMock()
sys.modules.setdefault("influxdb_client", _influx)
sys.modules.setdefault("influxdb_client.client", _influx.client)
sys.modules.setdefault("influxdb_client.client.write_api", _influx.client.write_api)

# Stub paho.mqtt (used by gate_bridge)
_paho = MagicMock()
sys.modules.setdefault("paho", _paho)
sys.modules.setdefault("paho.mqtt", _paho.mqtt)
sys.modules.setdefault("paho.mqtt.client", _paho.mqtt.client)
