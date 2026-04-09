"""
firebase_bridge.py — Firebase Admin SDK write helpers for the CV pipeline.

Provides a thin wrapper around firebase_admin.db with exponential-backoff
retry logic (max 3 attempts) on write failure.
"""

import logging
import time

import firebase_admin
from firebase_admin import credentials, db

logger = logging.getLogger(__name__)

# ── Retry configuration ───────────────────────────────────────────────────────
_MAX_ATTEMPTS = 3
_BACKOFF_BASE = 0.5  # seconds — doubles each attempt: 0.5 → 1.0 → 2.0


def _retry_write(fn, *args, **kwargs):
    """
    Execute *fn* with exponential backoff, up to _MAX_ATTEMPTS times.

    Args:
        fn:      Callable that performs the Firebase write.
        *args:   Positional arguments forwarded to *fn*.
        **kwargs: Keyword arguments forwarded to *fn*.

    Raises:
        Exception: Re-raises the last exception if all attempts fail.
    """
    last_exc: Exception | None = None
    for attempt in range(1, _MAX_ATTEMPTS + 1):
        try:
            fn(*args, **kwargs)
            return
        except Exception as exc:  # noqa: BLE001
            last_exc = exc
            wait = _BACKOFF_BASE * (2 ** (attempt - 1))
            logger.warning(
                "Firebase write failed (attempt %d/%d): %s — retrying in %.1fs",
                attempt,
                _MAX_ATTEMPTS,
                exc,
                wait,
            )
            if attempt < _MAX_ATTEMPTS:
                time.sleep(wait)
    logger.error("Firebase write failed after %d attempts: %s", _MAX_ATTEMPTS, last_exc)
    raise last_exc  # type: ignore[misc]


class FirebaseBridge:
    """
    Writes CV pipeline results to Firebase Realtime Database.

    Firebase must already be initialised (firebase_admin.initialize_app) before
    constructing this class.  If it has not been initialised, pass *cred_path*
    and *db_url* to perform initialisation here.

    Args:
        cred_path: Path to the service-account JSON file.  Only used when
                   firebase_admin has not yet been initialised.
        db_url:    Firebase Realtime Database URL.  Only used when
                   firebase_admin has not yet been initialised.
    """

    def __init__(self, cred_path: str | None = None, db_url: str | None = None):
        if not firebase_admin._apps:  # noqa: SLF001
            if cred_path is None or db_url is None:
                raise ValueError(
                    "firebase_admin is not initialised. "
                    "Provide cred_path and db_url to FirebaseBridge."
                )
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred, {"databaseURL": db_url})
            logger.info("Firebase initialised by FirebaseBridge.")

    # ── Public write methods ──────────────────────────────────────────────────

    def write_slot_status(
        self,
        slot_id: str,
        status: str,
        vehicle_type: str | None = None,
    ) -> None:
        """
        Write occupancy status (and optional vehicle type) for a slot.

        Firebase path: /slots/{slot_id}/status  (and /slots/{slot_id}/vehicleType)

        Args:
            slot_id:      Slot identifier, e.g. "A1".
            status:       One of 'available', 'occupied', 'reserved'.
            vehicle_type: 'ev', 'ice', or None.
        """
        payload: dict = {"status": status}
        if vehicle_type is not None:
            payload["vehicleType"] = vehicle_type

        def _write():
            db.reference(f"/slots/{slot_id}").update(payload)

        logger.debug("Writing slot status: %s → %s (vehicle=%s)", slot_id, status, vehicle_type)
        _retry_write(_write)

    def write_violation(
        self,
        slot_id: str,
        violation_type: str,
        timestamp: float,
    ) -> None:
        """
        Write a violation record for a slot.

        Firebase path: /slots/{slot_id}/violation

        Args:
            slot_id:        Slot identifier.
            violation_type: 'ice_in_ev_slot' or 'ev_no_cable'.
            timestamp:      Unix timestamp (seconds) of the violation.
        """
        payload = {
            "type": violation_type,
            "timestamp": timestamp,
            "slotId": slot_id,
        }

        def _write():
            db.reference(f"/slots/{slot_id}/violation").set(payload)

        logger.debug("Writing violation: %s → %s at %.0f", slot_id, violation_type, timestamp)
        _retry_write(_write)

    def write_gate_status(self, status: str) -> None:
        """
        Write the current gate status.

        Firebase path: /gate/status

        Args:
            status: One of 'ready', 'open', 'closed'.
        """
        def _write():
            db.reference("/gate/status").set(status)

        logger.debug("Writing gate status: %s", status)
        _retry_write(_write)

    def write_entry_detected(self, value: bool) -> None:
        """
        Write the entry-detected flag.

        Firebase path: /gate/entry_detected

        Args:
            value: True when a vehicle is detected at the gate entrance.
        """
        def _write():
            db.reference("/gate/entry_detected").set(value)

        logger.debug("Writing entry_detected: %s", value)
        _retry_write(_write)
