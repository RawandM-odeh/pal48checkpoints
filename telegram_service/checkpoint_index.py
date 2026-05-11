"""Load checkpoint doc ids and name/alias strings for Telegram matching."""

from __future__ import annotations

import logging
import threading
import time
from typing import Any

from parser_ar import normalize_ar

log = logging.getLogger(__name__)

_lock = threading.Lock()
# (doc_id, variant) sorted by len(normalize_ar(variant)) descending
_flat: list[tuple[str, str]] = []
_loaded_at: float = 0.0


def _flatten(rows: list[tuple[str, list[str]]]) -> list[tuple[str, str]]:
    flat: list[tuple[str, str]] = []
    for doc_id, variants in rows:
        seen: set[str] = set()
        for v in variants:
            t = v.strip()
            if len(t) < 2 or t in seen:
                continue
            seen.add(t)
            flat.append((doc_id, t))
    flat.sort(key=lambda x: len(normalize_ar(x[1])), reverse=True)
    return flat


def _doc_variants(doc_id: str, data: dict[str, Any]) -> list[str]:
    out: list[str] = [doc_id]
    nar = data.get("name_ar")
    if isinstance(nar, str) and nar.strip():
        out.append(nar.strip())
    nen = data.get("name_en")
    if isinstance(nen, str) and nen.strip():
        out.append(nen.strip())
    raw_aliases = data.get("aliases")
    if isinstance(raw_aliases, list):
        for a in raw_aliases:
            if isinstance(a, str) and a.strip():
                out.append(a.strip())
    return out


def refresh(db) -> None:
    global _flat, _loaded_at
    rows: list[tuple[str, list[str]]] = []
    for doc in db.collection("checkpoints").stream():
        did = doc.id
        d = doc.to_dict() or {}
        rows.append((did, _doc_variants(did, d)))
    new_flat = _flatten(rows)
    with _lock:
        _flat = new_flat
        _loaded_at = time.time()
    log.info("Checkpoint index: %s documents, %s name variants", len(rows), len(new_flat))


def get_flat() -> list[tuple[str, str]]:
    with _lock:
        return list(_flat)


def age_seconds() -> float:
    with _lock:
        return max(0.0, time.time() - _loaded_at)


def ensure_loaded(db, max_age_sec: float = 900.0) -> None:
    """Load or refresh if stale (default 15 min)."""
    if age_seconds() > max_age_sec or not get_flat():
        refresh(db)
