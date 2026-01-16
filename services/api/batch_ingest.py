import firebase_admin
from firebase_admin import credentials, firestore
from app.core.config import settings
from app.services.pdf_ingestion import PDFIngestionService
from app.services.vector_store import VectorStoreService
import os

# Initialize Firebase (Standalone)
if not firebase_admin._apps:
    cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
    firebase_admin.initialize_app(cred, {
        'storageBucket': 'lumina-3b95f.firebasestorage.app'
    })

db = firestore.client()
vector_store = VectorStoreService()

def batch_ingest():
    print("Starting Batch Ingestion...")
    
    # scan all users (for now just assuming one user or scan all recursively)
    # Since structure is users/{uid}/subjects/{sid}/files/{fid}
    # We can use Collection Group Query to find all 'files' collections!
    
    files_query = db.collection_group('files').stream()
    
    count = 0
    for doc in files_query:
        data = doc.to_dict()
        filename = data.get('name')
        url = data.get('url')
        
        # We need the STORAGE PATH, not the URL.
        # usually stored as users/{uid}/subjects/{sid}/files/{filename}
        # But our metadata in Firestore MIGHT NOT have the full path explicitly saved?
        # Let's check what we saved in the Flutter app.
        # Flutter specific code saved: 'name', 'url', 'size_bytes', 'uploaded_at'
        # It did NOT save the 'path'.
        
        # We can reconstruct path from the doc reference!
        # doc.reference.path gives: users/UID/subjects/SID/files/DOC_ID
        # The file is stored at: users/UID/subjects/SID/files/FILENAME (sanitized?)
        
        # Wait, the FileRepository in Flutter saved it.
        # The storage path logic was: users/$uid/subjects/$subjectId/files/$filename
        
        # Let's extract parents
        # path: users/{uid}/subjects/{subject_id}/files/{doc_id}
        parent_subject = doc.reference.parent.parent
        subject_id = parent_subject.id
        
        parent_user = parent_subject.parent.parent
        uid = parent_user.id # This might be 'users' collection parent?
        # Actually doc.reference.path is "users/xyz/subjects/abc/files/123"
        # split by /
        segments = doc.reference.path.split('/')
        if len(segments) == 6:
            uid = segments[1]
            subject_id = segments[3]
            
            # Reconstruct Storage Path
            # NOTE: We sanitized filenames in Flutter later.
            # Ideally we should have stored 'storagePath' in Firestore.
            # logic: _storageRef(uid, subjectId, filename)
            # The filename in metadata is the display name (possibly unsanitized).
            # But we sanitized it before upload!
            # The filename saved in Firestore was the Sanitized one?
            # Let's check Flutter code:
            # await _filesRef(uid, subjectId).add({'name': filename...})
            # It saved the ORIGINAL filename or the SANITIZED one? 
            # It saved `filename` (variable).
            # The variable `filename` was passed to the function. 
            # In Flutter UI: `await fileRepo.uploadFile(..., filename: file.name)`
            # So it's the original filename (with spaces).
            
            # Update: I updated FileRepo to sanitize. 
            # "final safeFilename = filename.replaceAll...; ref = ...; _filesRef...add({'name': filename})"
            # So Firestore has "Original Name". Storage has "Sanitized Name".
            
            original_name = data.get('name')
            safe_filename = original_name.replace(r'[^a-zA-Z0-9._-]', '_') 
            # Wait, python regex replacement is different.
            import re
            safe_filename = re.sub(r'[^a-zA-Z0-9._-]', '_', original_name)
            
            storage_path = f"users/{uid}/subjects/{subject_id}/files/{safe_filename}"
            
            print(f"Processing: {storage_path}")
            
            try:
                # 1. Pipeline
                text = PDFIngestionService.process_file(storage_path)
                
                metadata = {
                    "subject_id": subject_id,
                    "filename": original_name,
                    "source": storage_path
                }
                
                vector_store.add_document(text, metadata)
                print(f"Successfully ingested: {original_name}")
                count += 1
            except Exception as e:
                print(f"Failed to ingest {original_name}: {e}")

    print(f"Batch Ingestion Complete. Processed {count} files.")

if __name__ == "__main__":
    batch_ingest()
