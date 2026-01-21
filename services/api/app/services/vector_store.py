from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_google_genai import GoogleGenerativeAIEmbeddings
from langchain_google_firestore import FirestoreVectorStore
from app.core.config import settings
from google.cloud import firestore
import os

class VectorStoreService:
    def __init__(self):
        if not settings.GOOGLE_API_KEY:
            raise ValueError("GOOGLE_API_KEY is missing in environment variables")
            
        self.embeddings = GoogleGenerativeAIEmbeddings(
            model="models/text-embedding-004",
            google_api_key=settings.GOOGLE_API_KEY
        )
        
        # Initialize Firestore Client
        # We rely on the env var GOOGLE_APPLICATION_CREDENTIALS being set, 
        # which is standard for Firebase Admin SDK usage.
        self.db = firestore.Client()
        self.collection_name = "vector_store_data"

        # Initialize FirestoreVectorStore
        self.vector_db = FirestoreVectorStore(
            client=self.db,
            collection=self.collection_name,
            embedding_service=self.embeddings
        )

    def split_text(self, text: str):
        splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000,
            chunk_overlap=200,
            separators=["\n\n", "\n", " ", ""]
        )
        return splitter.split_text(text)

    def add_document(self, text: str, metadata: dict):
        chunks = self.split_text(text)
        print(f"Splitting into {len(chunks)} chunks...")
        
        # Add chunks to vector store
        # Metadata is replicated for each chunk (e.g., subject_id, file_name)
        metadatas = [metadata for _ in chunks]
        
        self.vector_db.add_texts(
            texts=chunks,
            metadatas=metadatas
        )
        print("Documents added to Vector DB.")

    def delete_document(self, filename: str):
        """Removes all chunks associated with a specific filename."""
        print(f"Deleting document: {filename}")
        try:
           # Firestore Vector Store doesn't expose a clean 'delete by metadata' yet via LangChain
           # So we use standard Firestore query.
           # The document chunks are stored in 'self.collection_name'.
           # LangChain stores metadata in the 'metadata' map field.
           
           docs = self.db.collection(self.collection_name)\
                    .where("metadata.filename", "==", filename)\
                    .stream()
           
           deleted_count = 0
           batch = self.db.batch()
           
           for doc in docs:
               batch.delete(doc.reference)
               deleted_count += 1
               if deleted_count % 400 == 0: # Firestore batch limit is 500
                   batch.commit()
                   batch = self.db.batch()
           
           if deleted_count > 0:
               batch.commit() # Commit remaining
               
           print(f"Successfully deleted {deleted_count} chunks for {filename}")
        except Exception as e:
           print(f"Error deleting from Vector DB: {e}")

    def similarity_search(self, query: str, subject_id: str = None, k=4):
        # Filter by subject_id ONLY if provided
        # LCV for Firestore uses 'filters' argument usually, but LangChain's interface is standard
        # However, for Firestore, we might need to be specific about 'metadata.subject_id'
        # The standard similarity_search takes filter={'key': 'val'}
        # Let's try standard first. If it fails, we check internal implementation.
        # langchain-google-firestore supports standard dict filters matching metadata.
        
        # NOTE: Using filters often requires a Composite Index in Firestore if combining with vector search.
        # For now, let's keep it simple.
        
        search_kwargs = {"k": k}
        if subject_id:
            search_kwargs["filter"] = {"subject_id": subject_id} # LangChain usually maps this to metadata.subject_id
            
        return self.vector_db.similarity_search(
            query, 
            **search_kwargs
        )
    
    def similarity_search_with_retry(self, query: str, subject_id: str = None, k=4):
        try:
            return self.similarity_search(query, subject_id, k)
        except Exception as e:
            # Check if it's a gRPC error with the link
            error_str = str(e)
            if "https://console.firebase.google.com" in error_str:
                print("\n" + "="*80)
                print("ACTION REQUIRED: CREATE VECTOR INDEX")
                print("Click this link to create the missing index:")
                # Extract link (simple heuristic)
                start = error_str.find("https://")
                end = error_str.find(" ", start)
                if end == -1: end = len(error_str)
                link = error_str[start:end]
                print(link)
                print("="*80 + "\n")
            raise e
    
    def as_retriever(self, subject_id: str = None):
        search_kwargs = {}
        if subject_id:
            search_kwargs["filter"] = {"subject_id": subject_id}
            
        return self.vector_db.as_retriever(
            search_kwargs=search_kwargs
        )
