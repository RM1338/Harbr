"""
test_smoke.py — Smoke test: Flutter/Dart source files must NOT use MQTT directly.

11.6: Walk all .dart files in the lib/ directory and verify none of them contain
MQTT-related imports or instantiations. Flutter communicates exclusively through
Firebase; the Python backend is the sole MQTT client.

Forbidden patterns:
  - import 'package:mqtt...
  - import 'package:mqtt_client...
  - MqttClient
  - MqttServerClient
  - paho  (would indicate a Python-style import in Dart — shouldn't exist)
  - mqtt_client  (pub.dev package name)
"""

import os
import re
from pathlib import Path

import pytest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _find_dart_files(root: Path):
    """Recursively yield all .dart files under *root*."""
    for path in root.rglob("*.dart"):
        yield path


def _lib_root() -> Path:
    """Return the absolute path to the Flutter lib/ directory."""
    # This test lives at hardware/cv_pipeline/tests/test_smoke.py
    # The workspace root is three levels up.
    here = Path(__file__).resolve().parent          # .../hardware/cv_pipeline/tests/
    workspace = here.parent.parent.parent           # workspace root
    lib_dir = workspace / "lib"
    return lib_dir


# Patterns that must NOT appear in any Dart source file
_FORBIDDEN_PATTERNS = [
    re.compile(r"import\s+['\"]package:mqtt", re.IGNORECASE),
    re.compile(r"import\s+['\"]package:mqtt_client", re.IGNORECASE),
    re.compile(r"\bMqttClient\b"),
    re.compile(r"\bMqttServerClient\b"),
    re.compile(r"\bMqttBrowserClient\b"),
    re.compile(r"\bpaho\b", re.IGNORECASE),
    re.compile(r"mqtt_client", re.IGNORECASE),
]


# ---------------------------------------------------------------------------
# 11.6 — No MQTT in Flutter/Dart source files
# ---------------------------------------------------------------------------

class TestNoMqttInFlutterSource:
    """
    11.6: Verify that no Flutter/Dart source file in lib/ imports or
    instantiates an MQTT client. Flutter must only communicate via Firebase.
    """

    def test_lib_directory_exists(self):
        """The lib/ directory must exist for the smoke test to be meaningful."""
        lib_dir = _lib_root()
        assert lib_dir.exists(), (
            f"lib/ directory not found at {lib_dir}. "
            "Ensure the test is run from the workspace root."
        )
        assert lib_dir.is_dir(), f"{lib_dir} is not a directory"

    def test_dart_files_found(self):
        """There must be at least one .dart file in lib/ to test."""
        lib_dir = _lib_root()
        dart_files = list(_find_dart_files(lib_dir))
        assert len(dart_files) > 0, (
            f"No .dart files found under {lib_dir}. "
            "The smoke test requires source files to scan."
        )

    def test_no_mqtt_import_in_any_dart_file(self):
        """No .dart file in lib/ may import an MQTT package."""
        lib_dir = _lib_root()
        violations = []

        for dart_file in _find_dart_files(lib_dir):
            content = dart_file.read_text(encoding="utf-8")
            for line_no, line in enumerate(content.splitlines(), start=1):
                for pattern in _FORBIDDEN_PATTERNS:
                    if pattern.search(line):
                        violations.append(
                            f"{dart_file.relative_to(lib_dir.parent)}:{line_no}: "
                            f"forbidden pattern {pattern.pattern!r} found in: {line.strip()!r}"
                        )

        assert violations == [], (
            "Flutter source files must NOT use MQTT directly.\n"
            "Violations found:\n" + "\n".join(violations)
        )

    def test_no_mqtt_client_instantiation(self):
        """No .dart file may instantiate MqttClient or related classes."""
        lib_dir = _lib_root()
        mqtt_instantiation = re.compile(
            r"\b(MqttClient|MqttServerClient|MqttBrowserClient)\s*\(",
        )
        violations = []

        for dart_file in _find_dart_files(lib_dir):
            content = dart_file.read_text(encoding="utf-8")
            for line_no, line in enumerate(content.splitlines(), start=1):
                if mqtt_instantiation.search(line):
                    violations.append(
                        f"{dart_file.relative_to(lib_dir.parent)}:{line_no}: "
                        f"MQTT instantiation found: {line.strip()!r}"
                    )

        assert violations == [], (
            "Flutter source files must NOT instantiate MQTT clients.\n"
            "Violations found:\n" + "\n".join(violations)
        )

    def test_no_paho_reference_in_dart_files(self):
        """No .dart file may reference 'paho' (Python MQTT library)."""
        lib_dir = _lib_root()
        paho_pattern = re.compile(r"\bpaho\b", re.IGNORECASE)
        violations = []

        for dart_file in _find_dart_files(lib_dir):
            content = dart_file.read_text(encoding="utf-8")
            for line_no, line in enumerate(content.splitlines(), start=1):
                if paho_pattern.search(line):
                    violations.append(
                        f"{dart_file.relative_to(lib_dir.parent)}:{line_no}: "
                        f"'paho' reference found: {line.strip()!r}"
                    )

        assert violations == [], (
            "Flutter source files must NOT reference 'paho'.\n"
            "Violations found:\n" + "\n".join(violations)
        )

    def test_scanned_file_count_is_reasonable(self):
        """Sanity check: the scan covers a reasonable number of Dart files."""
        lib_dir = _lib_root()
        dart_files = list(_find_dart_files(lib_dir))
        # The project has at least main.dart and several datasource files
        assert len(dart_files) >= 5, (
            f"Expected at least 5 .dart files, found {len(dart_files)}. "
            "The smoke test may not be scanning the correct directory."
        )
