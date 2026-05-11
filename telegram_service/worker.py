"""
Listen to Telegram channels and optionally sync parsed Arabic lines to Firestore.

.env:
  TELEGRAM_SOURCE_CHAT_IDS=...
  GOOGLE_APPLICATION_CREDENTIALS=... (for Firestore)

Usage:
  .\\.venv\\Scripts\\Activate.ps1
  pip install -r requirements.txt
  python worker.py
"""

from __future__ import annotations

import asyncio
import logging
import os
from pathlib import Path

from dotenv import load_dotenv
from telethon import TelegramClient, events

import checkpoint_index
from chats_env import load_chat_ids
from checkpoint_index import ensure_loaded
from firebase_app import get_firestore_client, init_firebase
from firestore_updates import apply_all_for_message
from parser_ar import parse_message

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger("worker")


def _session_path_for_telethon() -> str:
    raw = os.environ.get("TELEGRAM_SESSION_PATH", "telegram").strip()
    if not raw:
        return "telegram"
    p = Path(raw)
    if p.suffix.lower() == ".session":
        p = p.with_suffix("")
    return str(p)


async def _main() -> None:
    env_path = Path(__file__).resolve().parent / ".env"
    if not env_path.is_file():
        raise SystemExit(
            f"Missing {env_path}\n"
            "Copy .env.example to .env, then set TELEGRAM_API_ID, TELEGRAM_API_HASH, "
            "and TELEGRAM_SOURCE_CHAT_IDS (or TELEGRAM_SOURCE_CHAT_ID)."
        )
    load_dotenv(env_path)

    firebase_ok = init_firebase()
    db = get_firestore_client() if firebase_ok else None
    if db is not None:
        ensure_loaded(db)
        log.info("Firestore + checkpoint index ready")
    else:
        log.warning("Firestore disabled — messages are logged only")

    try:
        chat_ids = load_chat_ids()
    except ValueError as e:
        raise SystemExit(
            f"{e}\n\n"
            f"Edit this file: {env_path}\n"
            "Add a line like (your four channels):\n"
            "  TELEGRAM_SOURCE_CHAT_IDS=-1001756020315,-1001429269676,"
            "-1001267214144,-1001992318151"
        ) from e
    api_id = int(os.environ["TELEGRAM_API_ID"])
    api_hash = os.environ["TELEGRAM_API_HASH"]
    session = _session_path_for_telethon()

    client = TelegramClient(session, api_id, api_hash)
    await client.start()

    log.info("Listening on %s chat(s): %s", len(chat_ids), chat_ids)

    @client.on(events.NewMessage(chats=chat_ids))
    async def on_message(event: events.NewMessage.Event) -> None:
        text = event.message.message or ""
        preview = (text[:200] + "…") if len(text) > 200 else text
        log.info("chat_id=%s msg_id=%s text=%r", event.chat_id, event.id, preview)

        if db is None:
            return

        if checkpoint_index.age_seconds() > 900:
            ensure_loaded(db)

        flat = checkpoint_index.get_flat()
        parsed = parse_message(text, flat)
        if not parsed:
            return

        def _run_firestore() -> int:
            return apply_all_for_message(
                db,
                int(event.chat_id),
                int(event.id),
                parsed,
                text_preview=text[:2000],
            )

        try:
            n = await asyncio.to_thread(_run_firestore)
            if n:
                log.info("Applied Firestore updates: %s", n)
        except Exception:
            log.exception("Firestore worker error")

    await client.run_until_disconnected()


if __name__ == "__main__":
    asyncio.run(_main())
