from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_google_genai import GoogleGenerativeAIEmbeddings
from langchain_google_firestore import FirestoreVectorStore
from app.core.config import settings
from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
import os

class CustomGoogleGenerativeAIEmbeddings(GoogleGenerativeAIEmbeddings):
    def embed_documents(self, texts: list[str], task_type: str = None) -> list[list[float]]:
        return super().embed_documents(texts, task_type=task_type, output_dimensionality=768)

    def embed_query(self, text: str, task_type: str = None) -> list[float]:
        return super().embed_query(text, task_type=task_type, output_dimensionality=768)

class VectorStoreService:
    def __init__(self):
        if not settings.GOOGLE_API_KEY:
            raise ValueError("GOOGLE_API_KEY is missing in environment variables")
            
        self.embeddings = CustomGoogleGenerativeAIEmbeddings(
            model="models/gemini-embedding-001",
            google_api_key=settings.GOOGLE_API_KEY
        )
        
        self.db = firestore.Client()
        self.collection_name = "vector_store_data"

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
        

        metadatas = [metadata for _ in chunks]
        
        self.vector_db.add_texts(
            texts=chunks,
            metadatas=metadatas
        )
        print("Documents added to Vector DB.")

    def delete_document(self, uid: str, filename: str):
        print(f"Deleting document: {filename} for user: {uid}")
        try:

           
           docs = self.db.collection(self.collection_name)\
                    .where("metadata.user_id", "==", uid)\
                    .where("metadata.filename", "==", filename)\
                    .stream()
           
           deleted_count = 0
           batch = self.db.batch()
           
           for doc in docs:
               batch.delete(doc.reference)
               deleted_count += 1
               if deleted_count % 400 == 0:
                   batch.commit()
                   batch = self.db.batch()
           
           if deleted_count > 0:
               batch.commit() 
               
           print(f"Successfully deleted {deleted_count} chunks for {filename}")
        except Exception as e:
           print(f"Error deleting from Vector DB: {e}")

    def similarity_search(self, query: str, user_id: str, k=10):
        query_embedding = self.embeddings.embed_query(query)
        import numpy as np
        from langchain_core.documents import Document
        
        docs_ref = self.db.collection(self.collection_name).where(filter=FieldFilter("metadata.user_id", "==", user_id))
            
        docs = docs_ref.stream()
        
        scored_docs = []
        for doc in docs:
            data = doc.to_dict()
            if "embedding" in data and "content" in data:
                emb = data["embedding"]
                score = np.dot(query_embedding, emb) / (np.linalg.norm(query_embedding) * np.linalg.norm(emb))
                scored_docs.append((score, data))
                
        scored_docs.sort(key=lambda x: x[0], reverse=True)
        
        results = []
        for score, data in scored_docs[:k]:
            results.append(Document(page_content=data["content"], metadata=data.get("metadata", {})))
            
        return results
    
    def similarity_search_with_retry(self, query: str, user_id: str, k=10):
        try:
            return self.similarity_search(query, user_id, k)
        except Exception as e:
            error_str = str(e)
            if "https://console.firebase.google.com" in error_str:
                print("\n" + "="*80)
                print("ACTION REQUIRED: CREATE VECTOR INDEX")
                print("Click this link to create the missing index:")
                start = error_str.find("https://")
                end = error_str.find(" ", start)
                if end == -1: end = len(error_str)
                link = error_str[start:end]
                print(link)
                print("="*80 + "\n")
            raise e
    
    def as_retriever(self, user_id: str):
        comp_filter = FieldFilter("metadata.user_id", "==", user_id)
        return self.vector_db.as_retriever(
            search_kwargs={"filters": comp_filter}
        )
