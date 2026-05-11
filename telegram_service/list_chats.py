"""
Print Telethon dialog ids for groups/channels (use for TELEGRAM_SOURCE_CHAT_ID).

Run from telegram_service/ after login.py (same .env + telegram.session).

Usage:
  .\\.venv\\Scripts\\Activate.ps1
  python list_chats.py
"""

from __future__ import annotations

import asyncio
import os
from pathlib import Path

from dotenv import load_dotenv
from telethon import TelegramClient


def _session_path_for_telethon() -> str:
    raw = os.environ.get("TELEGRAM_SESSION_PATH", "telegram").strip()
    if not raw:
        return "telegram"
    p = Path(raw)
    if p.suffix.lower() == ".session":
        p = p.with_suffix("")
    return str(p)


async def _main() -> None:
    load_dotenv(Path(__file__).resolve().parent / ".env")

    api_id = int(os.environ["TELEGRAM_API_ID"])
    api_hash = os.environ["TELEGRAM_API_HASH"]
    session = _session_path_for_telethon()

    client = TelegramClient(session, api_id, api_hash)
    await client.connect()
    if not await client.is_user_authorized():
        raise SystemExit("Not logged in. Run python login.py first.")
    print("id\t\t\ttype\t\tname")
    print("-" * 72)
    async for dialog in client.iter_dialogs():
        ent = dialog.entity
        kind = type(ent).__name__
        if dialog.is_group or dialog.is_channel:
            print(f"{dialog.id}\t{kind}\t{dialog.name}")
    await client.disconnect()
    print("-" * 72)
    print("Put ids in .env as TELEGRAM_SOURCE_CHAT_IDS=id1,id2,... (or one TELEGRAM_SOURCE_CHAT_ID)")


if __name__ == "__main__":
    asyncio.run(_main())
