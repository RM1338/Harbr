"""
gate_bridge.py — Firebase /gate/ listener ↔ HiveMQ MQTT bridge.

Responsibilities:
  • Listen to Firebase /gate/open_command → publish to HiveMQ "parking/gate/open"
  • Subscribe to MQTT "parking/gate/status" → write to Firebase /gate/status
  • Subscribe to MQTT "parking/gate/entry_detected" → write to Firebase /gate/entry_detected

HiveMQ Cloud requires TLS on port 8883.
paho-mqtt auto-reconnect is enabled via reconnect_delay_set().
"""

import json
import logging
import ssl

import paho.mqtt.client as mqtt
from firebase_admin import db

from .firebase_bridge import FirebaseBridge

logger = logging.getLogger(__name__)

# MQTT topics
_TOPIC_GATE_OPEN = "parking/gate/open"
_TOPIC_GATE_STATUS = "parking/gate/status"
_TOPIC_ENTRY_DETECTED = "parking/gate/entry_detected"


class GateBridge:
    """
    Bridges Firebase /gate/ commands to HiveMQ MQTT and vice-versa.

    Args:
        firebase_bridge: Initialised FirebaseBridge instance for writing state.
        mqtt_host:       HiveMQ Cloud broker hostname.
        mqtt_port:       Broker port (default 8883 for TLS).
        mqtt_username:   HiveMQ Cloud username.
        mqtt_password:   HiveMQ Cloud password.
    """

    def __init__(
        self,
        firebase_bridge: FirebaseBridge,
        mqtt_host: str,
        mqtt_port: int = 8883,
        mqtt_username: str = "",
        mqtt_password: str = "",
    ):
        self._fb = firebase_bridge
        self._mqtt_host = mqtt_host
        self._mqtt_port = mqtt_port
        self._mqtt_username = mqtt_username
        self._mqtt_password = mqtt_password

        self._mqtt_client = mqtt.Client()
        self._mqtt_client.username_pw_set(mqtt_username, mqtt_password)

        # TLS for HiveMQ Cloud
        self._mqtt_client.tls_set(cert_reqs=ssl.CERT_REQUIRED, tls_version=ssl.PROTOCOL_TLS)

        # Auto-reconnect: wait 1–30 s between attempts
        self._mqtt_client.reconnect_delay_set(min_delay=1, max_delay=30)

        self._mqtt_client.on_connect = self._on_mqtt_connect
        self._mqtt_client.on_disconnect = self._on_mqtt_disconnect
        self._mqtt_client.on_message = self._on_mqtt_message

    # ── Public API ────────────────────────────────────────────────────────────

    def start(self) -> None:
        """
        Connect to HiveMQ and attach the Firebase /gate/open_command listener.

        This method blocks on mqtt.loop_start() (non-blocking background thread)
        and then attaches the Firebase listener.  Call this from a daemon thread
        so it does not block the main pipeline loop.
        """
        logger.info(
            "GateBridge connecting to HiveMQ at %s:%d …",
            self._mqtt_host,
            self._mqtt_port,
        )
        self._mqtt_client.connect(self._mqtt_host, self._mqtt_port, keepalive=60)
        self._mqtt_client.loop_start()

        # Attach Firebase listener — this call blocks until the process exits
        logger.info("Attaching Firebase listener on /gate/open_command …")
        db.reference("/gate/open_command").listen(self._on_open_command)

    # ── Firebase callback ─────────────────────────────────────────────────────

    def _on_open_command(self, event) -> None:
        """
        Firebase SSE callback for /gate/open_command.

        Publishes to HiveMQ when the value is truthy, then clears the flag.

        Args:
            event: firebase_admin.db.Event with .data and .path attributes.
        """
        value = event.data
        if not value:
            return  # ignore False / None / clear events

        logger.info("Firebase /gate/open_command = %s → publishing to MQTT", value)
        try:
            self._mqtt_client.publish(_TOPIC_GATE_OPEN, payload="1", qos=1)
            logger.debug("Published to %s", _TOPIC_GATE_OPEN)
        except Exception as exc:  # noqa: BLE001
            logger.error("MQTT publish failed: %s", exc)

        # Clear the command flag so it doesn't re-fire on reconnect
        try:
            db.reference("/gate/open_command").set(False)
        except Exception as exc:  # noqa: BLE001
            logger.warning("Failed to clear /gate/open_command: %s", exc)

    # ── MQTT callbacks ────────────────────────────────────────────────────────

    def _on_mqtt_connect(self, client, userdata, flags, rc) -> None:
        if rc == 0:
            logger.info("GateBridge connected to HiveMQ.")
            client.subscribe(_TOPIC_GATE_STATUS, qos=1)
            client.subscribe(_TOPIC_ENTRY_DETECTED, qos=1)
            logger.debug(
                "Subscribed to %s and %s", _TOPIC_GATE_STATUS, _TOPIC_ENTRY_DETECTED
            )
        else:
            logger.error("GateBridge MQTT connection failed, rc=%d", rc)

    def _on_mqtt_disconnect(self, client, userdata, rc) -> None:
        if rc != 0:
            logger.warning("GateBridge MQTT disconnected unexpectedly (rc=%d) — reconnecting …", rc)

    def _on_mqtt_message(self, client, userdata, msg) -> None:
        """
        MQTT message callback.

        parking/gate/status        → write to Firebase /gate/status
        parking/gate/entry_detected → write to Firebase /gate/entry_detected
        """
        topic = msg.topic
        try:
            payload = msg.payload.decode("utf-8").strip()
            logger.debug("MQTT message on %s: %r", topic, payload)

            if topic == _TOPIC_GATE_STATUS:
                self._fb.write_gate_status(payload)

            elif topic == _TOPIC_ENTRY_DETECTED:
                # Accept "1", "true", "True" as truthy; everything else is False
                value = payload.lower() in ("1", "true")
                self._fb.write_entry_detected(value)

        except Exception as exc:  # noqa: BLE001
            logger.error("GateBridge error processing MQTT message on %s: %s", topic, exc)
