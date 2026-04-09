"""
compliance_timer.py — Per-slot EV charging compliance timers.
"""

import logging
import threading
from typing import Callable

logger = logging.getLogger(__name__)


class ComplianceTimer:
    """
    Manages per-slot compliance timers for EV charging enforcement.

    When a timer expires the slot_id is added to an internal expired set.
    An optional callback is invoked on expiry (e.g. to trigger a violation write).

    Args:
        on_expire: Optional callable(slot_id) invoked when a timer fires.
    """

    def __init__(self, on_expire: Callable[[str], None] | None = None):
        self._timers: dict[str, threading.Timer] = {}
        self._expired: set[str] = set()
        self._lock = threading.Lock()
        self._on_expire = on_expire

    def start(self, slot_id: str, timeout_seconds: int = 300) -> None:
        """
        Start (or restart) the compliance timer for a slot.

        If a timer is already running for this slot it is cancelled first.

        Args:
            slot_id:         Identifier of the parking slot.
            timeout_seconds: Seconds until the timer fires. Default 300 (5 min).
        """
        with self._lock:
            self._cancel_locked(slot_id)
            timer = threading.Timer(timeout_seconds, self._expire, args=(slot_id,))
            timer.daemon = True
            timer.start()
            self._timers[slot_id] = timer
            logger.debug("Compliance timer started for slot %s (%ds).", slot_id, timeout_seconds)

    def cancel(self, slot_id: str) -> None:
        """
        Cancel the compliance timer for a slot and clear its expired state.

        Args:
            slot_id: Identifier of the parking slot.
        """
        with self._lock:
            self._cancel_locked(slot_id)
            self._expired.discard(slot_id)
            logger.debug("Compliance timer cancelled for slot %s.", slot_id)

    def is_expired(self, slot_id: str) -> bool:
        """
        Check whether the compliance timer for a slot has expired.

        Args:
            slot_id: Identifier of the parking slot.

        Returns:
            True if the timer has fired and not been cancelled, False otherwise.
        """
        with self._lock:
            return slot_id in self._expired

    # ── Internal helpers ──────────────────────────────────────────────────────

    def _expire(self, slot_id: str) -> None:
        """Timer callback — marks slot as expired and invokes optional hook."""
        with self._lock:
            self._timers.pop(slot_id, None)
            self._expired.add(slot_id)
        logger.info("Compliance timer expired for slot %s.", slot_id)
        if self._on_expire is not None:
            try:
                self._on_expire(slot_id)
            except Exception as exc:  # noqa: BLE001
                logger.error("on_expire callback error for slot %s: %s", slot_id, exc)

    def _cancel_locked(self, slot_id: str) -> None:
        """Cancel an existing timer. Must be called with self._lock held."""
        timer = self._timers.pop(slot_id, None)
        if timer is not None:
            timer.cancel()
