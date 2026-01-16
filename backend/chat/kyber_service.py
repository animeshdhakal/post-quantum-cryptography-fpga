import os
import sys
import json
import pickle
import threading
from pathlib import Path

# Add kyber_py to sys.path
# Assuming we are in backend/chat/ or backend/
# kyber_py is in ../../kyber_py relative to this file
BASE_DIR = Path(__file__).resolve().parent.parent.parent
KYBER_PY_DIR = BASE_DIR / "kyber_py"
sys.path.append(str(KYBER_PY_DIR))

try:
    import kyber_funcs
except ImportError:
    # If the relative path didn't work, try assuming we are at project root (unlikely for django but possible)
    sys.path.append(os.path.abspath("kyber_py"))
    import kyber_funcs


class KyberService:
    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(KyberService, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        self._initialized = True
        self.lock = threading.Lock()
        self.keys_file = BASE_DIR / "backend" / "kyber_keys.pkl"
        # Instantiate Kyber with the global hw interface from kyber_funcs
        self.kyber = kyber_funcs.Kyber(kyber_funcs.hw)
        self._initialize_keys()

    def _initialize_keys(self):
        with self.lock:
            # Check if keys exist
            if os.path.exists(self.keys_file):
                print(f"Loading Kyber keys from {self.keys_file}")
                with open(self.keys_file, "rb") as f:
                    keys = pickle.load(f)
                    self.kyber.pk = keys["pk"]
                    self.kyber.sk = keys["sk"]
                    self.kyber.a_matrix = keys["a_matrix"]
            else:
                print("Generating new Kyber keys...")
                # Initialize HW (Wait for it if needed)
                # kyber_funcs.hw is already instantiated on import
                pk, sk = self.kyber.keygen()
                # Save keys
                with open(self.keys_file, "wb") as f:
                    pickle.dump(
                        {"pk": pk, "sk": sk, "a_matrix": self.kyber.a_matrix}, f
                    )
                print(f"Kyber keys generated and saved to {self.keys_file}")

    def encrypt(self, plaintext: str) -> str:
        """
        Encrypts plaintext using Kyber.
        Returns a JSON string containing the 'u' and 'v' vectors.
        """
        with self.lock:
            try:
                # self.kyber.encrypt returns (u, v) list of ints
                u, v = self.kyber.encrypt(plaintext)
                return json.dumps({"u": u, "v": v, "is_encrypted": True})
            except Exception as e:
                print(f"Encryption error: {e}")
                # Fallback to plaintext if encryption fails (for robustness)
                return plaintext

    def decrypt(self, ciphertext_json: str) -> str:
        """
        Decrypts a JSON string containing 'u' and 'v' vectors.
        Returns the plaintext string.
        """
        if not ciphertext_json:
            return ""

        with self.lock:
            try:
                # Try to parse JSON
                try:
                    data = json.loads(ciphertext_json)
                except json.JSONDecodeError:
                    # Not JSON, assume plaintext (migration support)
                    return ciphertext_json

                if not isinstance(data, dict) or "u" not in data or "v" not in data:
                    return ciphertext_json

                u = data["u"]
                v = data["v"]

                res = self.kyber.decrypt(u, v)
                # Remove null bytes or artifacts if any (Kyber decode might have padding)
                return res.replace("\x00", "")
            except Exception as e:
                print(f"Decryption error: {e}")
                return "[Decryption Failed]"


# Global instance
kyber_service = KyberService()
