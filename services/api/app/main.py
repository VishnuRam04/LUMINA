from fastapi import FastAPI, HTTPException
import os
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
    # Set default credentials for Firestore Client
    # This must be done before initializing FirestoreVectorStore which initializes firestore.Client()
    # firestore.Client() looks for GOOGLE_APPLICATION_CREDENTIALS env var or gcloud default.
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "serviceAccountKey.json"
    
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
    history: list[dict] = [] # [{'role': 'user', 'content': '...'}, ...]

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
            
            # 3. Generate Flashcards (Async background preferred, but blocked here for simplicity)
            try:
                from app.services.flashcards import FlashcardService
                fc_service = FlashcardService()
                await fc_service.generate_and_save(
                    subject_id=request.subject_id,
                    text_content=text,
                    file_id=request.filename, # Using filename as file_id for now or hash
                    count=10
                )
                print(f"Flashcards generated for {request.filename}")
            except Exception as fc_e:
                print(f"Warning: Flashcard generation failed: {fc_e}")
                
            return {"status": "success", "message": "File processed, indexed, and flashcards generated"}
        else:
            raise HTTPException(status_code=500, detail="Vector Store not initialized")
            
    except Exception as e:
        print(f"Error processing file: {e}")
        raise HTTPException(status_code=500, detail=str(e))

class DeleteRequest(BaseModel):
    filename: str

@app.post("/delete")
async def delete_file(request: DeleteRequest):
    try:
        if vector_store:
            vector_store.delete_document(request.filename)
            return {"status": "success", "message": f"Deleted {request.filename}"}
        else:
            raise HTTPException(status_code=500, detail="Vector Store not initialized")
    except Exception as e:
        print(f"Error deleting file: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/chat")
async def chat(request: ChatRequest):
    try:
        if not vector_store or not chat_service:
            raise HTTPException(status_code=500, detail="Services not initialized")
            
        # 1. Retrieve Context
        # Always search globally (subject_id=None)
        # Increase k to 10 for broader context
        context_docs = vector_store.similarity_search_with_retry(request.query, None, k=10)
        
        # 2. Generate Answer
        answer = chat_service.get_answer(request.query, context_docs, request.history)
        
        return {
            "answer": answer,
            "sources": [doc.metadata.get("filename") for doc in context_docs]
        }
    except Exception as e:
        print(f"Error generating answer: {e}")
        raise HTTPException(status_code=500, detail=str(e))

from app.routers import flashcards, quiz
app.include_router(flashcards.router, prefix="/flashcards", tags=["flashcards"])
app.include_router(quiz.router, prefix="/quiz", tags=["quiz"])
