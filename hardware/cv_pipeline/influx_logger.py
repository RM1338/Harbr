"""
influx_logger.py — InfluxDB Cloud event logger for the CV pipeline.

Non-critical path: all write failures are logged as warnings and swallowed
so that InfluxDB unavailability never crashes the pipeline.
"""

import logging
import time

from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS

logger = logging.getLogger(__name__)


class InfluxLogger:
    """
    Writes CV pipeline events to InfluxDB Cloud.

    All write failures are caught and logged as warnings — InfluxDB is
    considered a non-critical observability path.

    Args:
        url:    InfluxDB Cloud URL, e.g. "https://us-east-1-1.aws.cloud2.influxdata.com".
        token:  InfluxDB API token.
        org:    InfluxDB organisation name.
        bucket: Target bucket name.
    """

    def __init__(self, url: str, token: str, org: str, bucket: str):
        self._bucket = bucket
        self._org = org
        try:
            self._client = InfluxDBClient(url=url, token=token, org=org)
            self._write_api = self._client.write_api(write_options=SYNCHRONOUS)
            logger.info("InfluxDB client initialised (bucket=%s).", bucket)
        except Exception as exc:  # noqa: BLE001
            logger.warning("InfluxDB client init failed: %s — logging disabled.", exc)
            self._write_api = None

    # ── Public log methods ────────────────────────────────────────────────────

    def log_violation(
        self,
        slot_id: str,
        violation_type: str,
        vehicle_type: str,
        timestamp: float,
    ) -> None:
        """
        Log a parking violation event to InfluxDB.

        Measurement: parking_violations
        Tags:        slot, violation_type, vehicle_type
        Fields:      timestamp_unix (float)

        Args:
            slot_id:        Slot identifier, e.g. "A1".
            violation_type: 'ice_in_ev_slot' or 'ev_no_cable'.
            vehicle_type:   'ev' or 'ice'.
            timestamp:      Unix timestamp (seconds) of the violation.
        """
        if self._write_api is None:
            return

        try:
            point = (
                Point("parking_violations")
                .tag("slot", slot_id)
                .tag("violation_type", violation_type)
                .tag("vehicle_type", vehicle_type)
                .field("timestamp_unix", timestamp)
                .time(int(timestamp * 1_000_000_000))  # nanoseconds
            )
            self._write_api.write(bucket=self._bucket, org=self._org, record=point)
            logger.debug(
                "InfluxDB violation logged: slot=%s type=%s", slot_id, violation_type
            )
        except Exception as exc:  # noqa: BLE001
            logger.warning("InfluxDB log_violation failed: %s", exc)

    def log_slot_status(self, slot_id: str, status: str) -> None:
        """
        Log a slot occupancy status change to InfluxDB.

        Measurement: parking_slots
        Tags:        slot
        Fields:      status (string)

        Args:
            slot_id: Slot identifier, e.g. "A1".
            status:  One of 'available', 'occupied', 'reserved'.
        """
        if self._write_api is None:
            return

        try:
            point = (
                Point("parking_slots")
                .tag("slot", slot_id)
                .field("status", status)
                .time(int(time.time() * 1_000_000_000))  # nanoseconds
            )
            self._write_api.write(bucket=self._bucket, org=self._org, record=point)
            logger.debug("InfluxDB slot status logged: slot=%s status=%s", slot_id, status)
        except Exception as exc:  # noqa: BLE001
            logger.warning("InfluxDB log_slot_status failed: %s", exc)
