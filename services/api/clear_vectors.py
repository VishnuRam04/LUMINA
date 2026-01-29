import firebase_admin
from firebase_admin import credentials, firestore
import os

# Initialize Firebase (Standalone script)
cred_path = "serviceAccountKey.json"
if not os.path.exists(cred_path):
    print(f"Error: {cred_path} not found.")
    exit(1)

cred = credentials.Certificate(cred_path)
firebase_admin.initialize_app(cred)

db = firestore.client()
COLLECTION_NAME = "vector_store_data"

def delete_collection(coll_ref, batch_size):
    docs = coll_ref.limit(batch_size).stream()
    deleted = 0

    for doc in docs:
        print(f'Deleting doc {doc.id} => {doc.to_dict().get("metadata", {}).get("filename", "No Name")}')
        doc.reference.delete()
        deleted += 1

    if deleted >= batch_size:
        return delete_collection(coll_ref, batch_size)

print(f"Deleting all documents in collection: {COLLECTION_NAME}...")
delete_collection(db.collection(COLLECTION_NAME), 100)
print("Done! Collection cleared.")
