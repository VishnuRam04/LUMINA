from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_google_genai import GoogleGenerativeAIEmbeddings
from langchain_community.vectorstores import Chroma
from app.core.config import settings
import os

class VectorStoreService:
    def __init__(self):
        if not settings.GOOGLE_API_KEY:
            raise ValueError("GOOGLE_API_KEY is missing in environment variables")
            
        self.embeddings = GoogleGenerativeAIEmbeddings(
            model="models/text-embedding-004",
            google_api_key=settings.GOOGLE_API_KEY
        )
        
        self.persist_directory = "./chroma_db"
        
        # Initialize or load ChromaDB
        self.vector_db = Chroma(
            persist_directory=self.persist_directory,
            embedding_function=self.embeddings
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

    def similarity_search(self, query: str, subject_id: str = None, k=4):
        # Filter by subject_id ONLY if provided
        search_kwargs = {"k": k}
        if subject_id:
            search_kwargs["filter"] = {"subject_id": subject_id}
            
        return self.vector_db.similarity_search(
            query, 
            **search_kwargs
        )
    
    def as_retriever(self, subject_id: str = None):
        search_kwargs = {}
        if subject_id:
            search_kwargs["filter"] = {"subject_id": subject_id}
            
        return self.vector_db.as_retriever(
            search_kwargs=search_kwargs
        )
