from google.cloud import firestore_admin_v1
from google.cloud.firestore_admin_v1.types import Index, Field
import os

# Set creds locally
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "serviceAccountKey.json"

def create_vector_index():
    print("Initializing Firestore Admin Client...")
    try:
        # Use the Admin API client (separate from standard Client)
        client = firestore_admin_v1.FirestoreAdminClient()
    except Exception as e:
        print(f"Error initializing Admin Client: {e}")
        return

    project_id = "lumina-3b95f"
    # Format: projects/{project_id}/databases/{database_id}/collectionGroups/{collection_id}
    parent = f"projects/{project_id}/databases/(default)/collectionGroups/vector_store_data"

    print(f"Defining Index for: {parent}")

    # 1. Define the Index
    my_index = Index()
    my_index.query_scope = Index.QueryScope.COLLECTION
    
    # 2. Vector Field (embedding)
    vec_field = Index.IndexField()
    vec_field.field_path = "embedding"
    vec_field.vector_config = Index.IndexField.VectorConfig(
        dimension=768,
        flat={} # Flat index (exact) or could use generic
    )
    
    # 3. Add field to index
    my_index.fields = [vec_field]

    try:
        print("Sending Create Index Request...")
        # Note: This returns an Operation (async)
        operation = client.create_index(parent=parent, index=my_index)
        print("\n✅ SUCCESS! Index creation started.")
        print(f"Operation Name: {operation.operation.name}")
        print("It will take ~5-10 minutes to complete.")
        print("You can check status in Firebase Console.")
        
    except Exception as e:
        print(f"\n❌ FAILED: {e}")
        if "already exists" in str(e):
             print("(This is good! It means it's already creating.)")
        if "PermissionDenied" in str(e):
            print("\n⚠️ PERMISSION ERROR:")
            print("Your 'serviceAccountKey.json' does not have 'Cloud Datastore Index Admin' role.")
            print("You MUST go to Firebase Console IAM settings and add this role to the service account.")

if __name__ == "__main__":
    create_vector_index()
