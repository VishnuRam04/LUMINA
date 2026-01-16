from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from app.core.firebase import init_firebase
from app.services.pdf_ingestion import PDFIngestionService
from app.services.vector_store import VectorStoreService
from app.services.chat_gen import ChatGenService

app = FastAPI(title="Lumina API")

# Initialize Services
# Note: In production, these might be singletons or dependency injected
vector_store = None
chat_service = None

@app.on_event("startup")
async def startup_event():
    init_firebase()
    global vector_store, chat_service
    # Initialize these only on startup to catch config errors early
    try:
        vector_store = VectorStoreService()
        chat_service = ChatGenService()
    except Exception as e:
        print(f"Error initializing services: {e}")

from typing import Optional

# Request Models
class IngestRequest(BaseModel):
    file_path: str
    subject_id: str
    filename: str

class ChatRequest(BaseModel):
    query: str
    subject_id: Optional[str] = None # Optional: If None, searches ALL subjects

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/ingest")
async def ingest_file(request: IngestRequest):
    try:
        # 1. Download & Extract
        text = PDFIngestionService.process_file(request.file_path)
        
        # 2. Store in Vector DB
        metadata = {
            "subject_id": request.subject_id,
            "filename": request.filename,
            "source": request.file_path
        }
        
        if vector_store:
            vector_store.add_document(text, metadata)
            return {"status": "success", "message": "File processed and indexed"}
        else:
            raise HTTPException(status_code=500, detail="Vector Store not initialized")
            
    except Exception as e:
        print(f"Error processing file: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/chat")
async def chat(request: ChatRequest):
    try:
        if not vector_store or not chat_service:
            raise HTTPException(status_code=500, detail="Services not initialized")
            
        # 1. Retrieve Context
        context_docs = vector_store.similarity_search(request.query, request.subject_id)
        
        # 2. Generate Answer
        answer = chat_service.get_answer(request.query, context_docs)
        
        return {
            "answer": answer,
            "sources": [doc.metadata.get("filename") for doc in context_docs]
        }
    except Exception as e:
        print(f"Error generating answer: {e}")
        raise HTTPException(status_code=500, detail=str(e))
