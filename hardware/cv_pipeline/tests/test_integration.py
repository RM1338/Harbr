"""
test_integration.py — Python integration tests for GateBridge.

11.4 — GateBridge publishes to MQTT mock when Firebase /gate/open_command is set to true
11.5 — GateBridge writes to Firebase /gate/status when MQTT gate status message received
"""

import sys
import os
from unittest.mock import MagicMock, call

import pytest

# conftest.py stubs firebase_admin, influxdb_client, and paho.mqtt before
# any cv_pipeline module is imported.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from cv_pipeline.gate_bridge import GateBridge
from cv_pipeline.firebase_bridge import FirebaseBridge


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_gate_bridge(mqtt_client=None, firebase_bridge=None):
    """
    Construct a GateBridge with injected mocks, bypassing real MQTT/TLS setup.

    We patch the internal _mqtt_client after construction so the constructor's
    TLS/connect calls are never reached.
    """
    mock_fb = firebase_bridge or MagicMock(spec=FirebaseBridge)
    bridge = GateBridge.__new__(GateBridge)
    bridge._fb = mock_fb
    bridge._mqtt_host = "mock-host"
    bridge._mqtt_port = 8883
    bridge._mqtt_username = ""
    bridge._mqtt_password = ""
    bridge._mqtt_client = mqtt_client or MagicMock()
    return bridge


def _make_event(data):
    """Create a minimal Firebase event stub with a .data attribute."""
    event = MagicMock()
    event.data = data
    return event


def _make_mqtt_message(topic: str, payload: str):
    """Create a minimal paho MQTT message stub."""
    msg = MagicMock()
    msg.topic = topic
    msg.payload = payload.encode("utf-8")
    return msg


# ---------------------------------------------------------------------------
# 11.4 — GateBridge publishes to MQTT when Firebase /gate/open_command = true
# ---------------------------------------------------------------------------

class TestGateBridgePublishesOnOpenCommand:
    """
    11.4: When Firebase /gate/open_command is set to true, GateBridge must
    publish to the "parking/gate/open" MQTT topic.
    """

    def test_open_command_true_publishes_to_mqtt(self):
        """_on_open_command(event.data=True) calls mqtt_client.publish with parking/gate/open."""
        mock_mqtt = MagicMock()
        bridge = _make_gate_bridge(mqtt_client=mock_mqtt)

        event = _make_event(True)
        bridge._on_open_command(event)

        mock_mqtt.publish.assert_called_once_with(
            "parking/gate/open", payload="1", qos=1
        )

    def test_open_command_false_does_not_publish(self):
        """_on_open_command(event.data=False) must NOT publish to MQTT."""
        mock_mqtt = MagicMock()
        bridge = _make_gate_bridge(mqtt_client=mock_mqtt)

        event = _make_event(False)
        bridge._on_open_command(event)

        mock_mqtt.publish.assert_not_called()

    def test_open_command_none_does_not_publish(self):
        """_on_open_command(event.data=None) must NOT publish to MQTT."""
        mock_mqtt = MagicMock()
        bridge = _make_gate_bridge(mqtt_client=mock_mqtt)

        event = _make_event(None)
        bridge._on_open_command(event)

        mock_mqtt.publish.assert_not_called()

    def test_open_command_true_clears_firebase_flag(self):
        """After publishing, GateBridge must clear /gate/open_command by setting False."""
        mock_mqtt = MagicMock()
        # We need a real-ish firebase_admin.db mock to capture the set() call
        import sys
        mock_db = sys.modules["firebase_admin.db"]
        mock_ref = MagicMock()
        mock_db.reference.return_value = mock_ref

        bridge = _make_gate_bridge(mqtt_client=mock_mqtt)
        event = _make_event(True)
        bridge._on_open_command(event)

        # The bridge should have called db.reference("/gate/open_command").set(False)
        mock_db.reference.assert_called_with("/gate/open_command")
        mock_ref.set.assert_called_with(False)

    def test_open_command_publishes_correct_topic(self):
        """The published topic must be exactly 'parking/gate/open'."""
        mock_mqtt = MagicMock()
        bridge = _make_gate_bridge(mqtt_client=mock_mqtt)

        bridge._on_open_command(_make_event(True))

        published_topic = mock_mqtt.publish.call_args[0][0]
        assert published_topic == "parking/gate/open", (
            f"Expected topic 'parking/gate/open', got {published_topic!r}"
        )


# ---------------------------------------------------------------------------
# 11.5 — GateBridge writes to Firebase /gate/status on MQTT gate status message
# ---------------------------------------------------------------------------

class TestGateBridgeWritesFirebaseOnMqttMessage:
    """
    11.5: When an MQTT message arrives on "parking/gate/status", GateBridge
    must call firebase_bridge.write_gate_status() with the payload string.
    """

    def test_mqtt_gate_status_open_writes_firebase(self):
        """MQTT 'parking/gate/status' payload 'open' → write_gate_status('open')."""
        mock_fb = MagicMock(spec=FirebaseBridge)
        bridge = _make_gate_bridge(firebase_bridge=mock_fb)

        msg = _make_mqtt_message("parking/gate/status", "open")
        bridge._on_mqtt_message(client=None, userdata=None, msg=msg)

        mock_fb.write_gate_status.assert_called_once_with("open")

    def test_mqtt_gate_status_closed_writes_firebase(self):
        """MQTT 'parking/gate/status' payload 'closed' → write_gate_status('closed')."""
        mock_fb = MagicMock(spec=FirebaseBridge)
        bridge = _make_gate_bridge(firebase_bridge=mock_fb)

        msg = _make_mqtt_message("parking/gate/status", "closed")
        bridge._on_mqtt_message(client=None, userdata=None, msg=msg)

        mock_fb.write_gate_status.assert_called_once_with("closed")

    def test_mqtt_gate_status_ready_writes_firebase(self):
        """MQTT 'parking/gate/status' payload 'ready' → write_gate_status('ready')."""
        mock_fb = MagicMock(spec=FirebaseBridge)
        bridge = _make_gate_bridge(firebase_bridge=mock_fb)

        msg = _make_mqtt_message("parking/gate/status", "ready")
        bridge._on_mqtt_message(client=None, userdata=None, msg=msg)

        mock_fb.write_gate_status.assert_called_once_with("ready")

    def test_mqtt_gate_status_does_not_call_entry_detected(self):
        """A gate/status message must NOT call write_entry_detected."""
        mock_fb = MagicMock(spec=FirebaseBridge)
        bridge = _make_gate_bridge(firebase_bridge=mock_fb)

        msg = _make_mqtt_message("parking/gate/status", "open")
        bridge._on_mqtt_message(client=None, userdata=None, msg=msg)

        mock_fb.write_entry_detected.assert_not_called()

    def test_mqtt_entry_detected_true_writes_firebase(self):
        """MQTT 'parking/gate/entry_detected' payload '1' → write_entry_detected(True)."""
        mock_fb = MagicMock(spec=FirebaseBridge)
        bridge = _make_gate_bridge(firebase_bridge=mock_fb)

        msg = _make_mqtt_message("parking/gate/entry_detected", "1")
        bridge._on_mqtt_message(client=None, userdata=None, msg=msg)

        mock_fb.write_entry_detected.assert_called_once_with(True)

    def test_mqtt_entry_detected_false_writes_firebase(self):
        """MQTT 'parking/gate/entry_detected' payload '0' → write_entry_detected(False)."""
        mock_fb = MagicMock(spec=FirebaseBridge)
        bridge = _make_gate_bridge(firebase_bridge=mock_fb)

        msg = _make_mqtt_message("parking/gate/entry_detected", "0")
        bridge._on_mqtt_message(client=None, userdata=None, msg=msg)

        mock_fb.write_entry_detected.assert_called_once_with(False)

    def test_mqtt_gate_status_payload_is_stripped(self):
        """Whitespace in the MQTT payload must be stripped before writing."""
        mock_fb = MagicMock(spec=FirebaseBridge)
        bridge = _make_gate_bridge(firebase_bridge=mock_fb)

        msg = _make_mqtt_message("parking/gate/status", "  open  ")
        bridge._on_mqtt_message(client=None, userdata=None, msg=msg)

        mock_fb.write_gate_status.assert_called_once_with("open")
