"""Apply Telegram-parsed updates to Firestore checkpoints (matches Flutter repository shape)."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

from firebase_admin import firestore

from parser_ar import DirectionMode, ParsedLine, normalize_status_token

log = logging.getLogger(__name__)

_MAX_HISTORY = 6
_SOURCE = "telegram"
_DEDUP_COLLECTION = "_telegram_ingest_dedup"


def _first_str(d: dict[str, Any], keys: list[str]) -> str | None:
    for k in keys:
        v = d.get(k)
        if isinstance(v, str) and v.strip():
            return v.strip()
    return None


def read_directions(d: dict[str, Any]) -> tuple[str, str]:
    legacy_raw = d.get("status")
    if isinstance(legacy_raw, str) and legacy_raw.strip():
        legacy = normalize_status_token(legacy_raw)
    else:
        legacy = "open"
    ent = _first_str(d, ["entrance_status", "entranceStatus"])
    ext = _first_str(d, ["exit_status", "exitStatus"])
    ne = normalize_status_token(ent) if ent else legacy
    nx = normalize_status_token(ext) if ext else legacy
    return ne, nx


def _next_status_history(
    previous: dict[str, Any],
    entrance: str,
    exit_s: str,
) -> list[dict[str, Any]]:
    raw = previous.get("status_history") or previous.get("statusHistory")
    existing: list[Any] = list(raw) if isinstance(raw, list) else []
    head_ts = firestore.Timestamp.from_datetime(datetime.now(timezone.utc))
    head: dict[str, Any] = {
        "at": head_ts,
        "entrance_status": entrance,
        "exit_status": exit_s,
        "source": _SOURCE,
    }
    next_list: list[Any] = [head, *existing]
    if len(next_list) > _MAX_HISTORY:
        next_list = next_list[:_MAX_HISTORY]
    return next_list  # type: ignore[return-value]


def _dedup_doc_id(chat_id: int, message_id: int) -> str:
    return f"{chat_id}_{message_id}"


def was_message_processed(db, chat_id: int, message_id: int) -> bool:
    doc_id = _dedup_doc_id(chat_id, message_id)
    snap = db.collection(_DEDUP_COLLECTION).document(doc_id).get()
    return snap.exists


def mark_message_processed(
    db,
    chat_id: int,
    message_id: int,
    *,
    preview: str,
) -> None:
    doc_id = _dedup_doc_id(chat_id, message_id)
    db.collection(_DEDUP_COLLECTION).document(doc_id).set(
        {
            "chat_id": chat_id,
            "message_id": message_id,
            "preview": preview[:500],
            "processed_at": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )


def _build_patch(
    d: dict[str, Any],
    direction: DirectionMode,
    new_status: str,
) -> dict[str, Any] | None:
    cur_e, cur_x = read_directions(d)
    update_entrance = direction in ("both", "entrance")
    update_exit = direction in ("both", "exit")
    ne = new_status if update_entrance else cur_e
    nx = new_status if update_exit else cur_x
    if ne == cur_e and nx == cur_x:
        return None
    hist = _next_status_history(d, ne, nx)
    patch: dict[str, Any] = {
        "entrance_status": ne,
        "exit_status": nx,
        "status_history": hist,
    }
    if update_entrance:
        patch["entrance_updated_at"] = firestore.SERVER_TIMESTAMP
        patch["entrance_source"] = _SOURCE
    if update_exit:
        patch["exit_updated_at"] = firestore.SERVER_TIMESTAMP
        patch["exit_source"] = _SOURCE
    return patch


@firestore.transactional
def _txn_apply_many(
    transaction: firestore.Transaction,
    work: list[tuple[firestore.DocumentReference, ParsedLine]],
) -> int:
    """Read all snapshots, then write. Returns count of docs updated."""
    rows: list[tuple[firestore.DocumentReference, ParsedLine, dict[str, Any] | None]] = []
    for doc_ref, parsed in work:
        snap = doc_ref.get(transaction=transaction)
        if not snap.exists:
            log.warning("Checkpoint doc missing: %s", doc_ref.id)
            rows.append((doc_ref, parsed, None))
            continue
        d = snap.to_dict() or {}
        patch = _build_patch(d, parsed.direction, parsed.status)
        rows.append((doc_ref, parsed, patch))

    n = 0
    for doc_ref, _parsed, patch in rows:
        if patch:
            transaction.update(doc_ref, patch)
            n += 1
    return n


def apply_parsed(db, parsed: ParsedLine) -> bool:
    """Single-checkpoint update (kept for tests / reuse)."""
    doc_ref = db.collection("checkpoints").document(parsed.checkpoint_id)
    transaction = db.transaction()
    n = _txn_apply_many(transaction, [(doc_ref, parsed)])
    return n > 0


def apply_all_for_message(
    db,
    chat_id: int,
    message_id: int,
    parsed_lines: list[ParsedLine],
    text_preview: str,
) -> int:
    """
    Dedup by (chat_id, message_id). One Firestore transaction for all lines.
    Last line wins if the same checkpoint appears twice.
    """
    if was_message_processed(db, chat_id, message_id):
        log.info("Skip duplicate telegram message chat=%s id=%s", chat_id, message_id)
        return 0
    if not parsed_lines:
        return 0

    merged: dict[str, ParsedLine] = {}
    for p in parsed_lines:
        merged[p.checkpoint_id] = p
    unique = list(merged.values())

    work = [
        (db.collection("checkpoints").document(p.checkpoint_id), p) for p in unique
    ]
    try:
        transaction = db.transaction()
        n_ok = _txn_apply_many(transaction, work)
        log.info(
            "telegram ingest chat=%s msg=%s updated_docs=%s lines=%s",
            chat_id,
            message_id,
            n_ok,
            len(unique),
        )
        mark_message_processed(db, chat_id, message_id, preview=text_preview)
        return n_ok
    except Exception:
        log.exception("Firestore transaction failed chat=%s id=%s", chat_id, message_id)
        return 0
