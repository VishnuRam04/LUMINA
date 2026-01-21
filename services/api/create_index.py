from google.cloud import firestore
from google.cloud.firestore_admin_v1 import FirestoreAdminClient
from google.cloud.firestore_admin_v1.types import Index, Field
import os

# Set creds
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "serviceAccountKey.json"

def create_vector_index():
    print("Creating Vector Index...")
    
    # 1. Get Project ID (from creds or manual)
    # We can parse it from serviceAccountKey if needed, but usually client detects it.
    # Actually, Administrative actions need the AdminClient.
    
    client = firestore.Client()
    project_id = client.project
    print(f"Project ID: {project_id}")
    
    admin_client = FirestoreAdminClient()
    parent = f"projects/{project_id}/databases/(default)/collectionGroups/vector_store_data"
    
    # Create Index Definition
    index = Index()
    index.query_scope = Index.QueryScope.COLLECTION
    
    # 1. Vector Field
    vector_field = Index.IndexField()
    vector_field.field_path = "embedding"
    vector_field.vector_config = Index.IndexField.VectorConfig(
        dimension=768,
        flat={} # or flat=Index.IndexField.VectorConfig.Flat()
    )
    
    # 2. Metadata Field (optional, but good for filtering)
    # For now, let's just do the vector one as that's the blocker.
    
    index.fields = [vector_field]
    
    try:
        # Note: Creating indexes via API is an async operation and might require permissions.
        # If this fails, we effectively proved we need the Console UI.
        operation = admin_client.create_index(parent=parent, index=index)
        print("Index creation initiated! It will take a few minutes.")
        print(f"Operation Name: {operation.operation.name}")
    except Exception as e:
        print(f"Failed to create index programmatically: {e}")
        print("\nFallback: Please go to 'https://console.firebase.google.com/project/lumina-3b95f/firestore/indexes'")

if __name__ == "__main__":
    create_vector_index()
