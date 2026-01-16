import firebase_admin
from firebase_admin import credentials, firestore, storage
from app.core.config import settings
import os

def init_firebase():
    if not firebase_admin._apps:
        if os.path.exists(settings.FIREBASE_CREDENTIALS_PATH):
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
            firebase_admin.initialize_app(cred, {
                'storageBucket': 'lumina-3b95f.firebasestorage.app'
            })
            print("Firebase Admin Initialized")
        else:
            print(f"Warning: Firebase credentials not found at {settings.FIREBASE_CREDENTIALS_PATH}")

def get_firestore():
    return firestore.client()

def get_storage_bucket():
    return storage.bucket()
