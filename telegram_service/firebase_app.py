"""Initialize Firebase Admin once when GOOGLE_APPLICATION_CREDENTIALS is set."""

from __future__ import annotations

import logging
import os
from pathlib import Path

log = logging.getLogger(__name__)


def init_firebase() -> bool:
    """
    Returns True if Firebase Admin is ready for Firestore.
    No-op if already initialized, or if env/path missing/invalid.
    """
    import firebase_admin
    from firebase_admin import credentials

    if firebase_admin._apps:
        return True

    raw = (os.environ.get("GOOGLE_APPLICATION_CREDENTIALS") or "").strip().strip('"')
    if not raw:
        log.warning("GOOGLE_APPLICATION_CREDENTIALS not set; Firestore disabled")
        return False

    path = Path(raw)
    if not path.is_file():
        log.warning("Firebase key file not found: %s; Firestore disabled", path)
        return False

    cred = credentials.Certificate(str(path))
    firebase_admin.initialize_app(cred)
    log.info("Firebase Admin initialized (key=%s)", path.name)
    return True


def get_firestore_client():
    """Returns Firestore client or None if Firebase was not initialized."""
    import firebase_admin
    from firebase_admin import firestore

    if not firebase_admin._apps:
        return None
    return firestore.client()
