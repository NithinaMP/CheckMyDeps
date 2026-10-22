"""Lets the test-suite import `app.*` on machines without Firebase credentials.

app/database/firestore.py initialises Firebase Admin at import time and needs
FIREBASE_CREDENTIALS_PATH. When that variable is NOT set we register a stand-in
module so `import app.api.auth` works. When it IS set (your normal dev setup),
nothing changes and the real module is used.
"""

import os
import sys
import types

if not os.getenv("FIREBASE_CREDENTIALS_PATH") and "app.database.firestore" not in sys.modules:
    stub = types.ModuleType("app.database.firestore")
    stub.db = None
    sys.modules["app.database.firestore"] = stub
