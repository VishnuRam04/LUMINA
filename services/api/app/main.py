from fastapi import FastAPI, HTTPException, Depends
import os
from pydantic import BaseModel
from app.core.firebase import init_firebase
from app.services.pdf_ingestion import PDFIngestionService
from app.services.vector_store import VectorStoreService
from app.services.chat_gen import ChatGenService
from app.dependencies.auth import get_current_user
from google.cloud import firestore

from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Lumina API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods (including OPTIONS)
    allow_headers=["*"],  # Allows all headers
)
vector_store = None
chat_service = None

from app.core.config import settings

@app.on_event("startup")
async def startup_event():

    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = settings.FIREBASE_CREDENTIALS_PATH
    
    init_firebase()
    global vector_store, chat_service
    try:
        vector_store = VectorStoreService()
        chat_service = ChatGenService()
    except Exception as e:
        print(f"Error initializing services: {e}")

from typing import Optional

class IngestRequest(BaseModel):
    file_path: str
    subject_id: str
    filename: str

class ChatRequest(BaseModel):
    query: str
    history: list[dict] = [] 
    image_base64: Optional[str] = None

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/ingest")
async def ingest_file(request: IngestRequest, user: dict = Depends(get_current_user)):
    try:
        uid = user['uid']
        text = PDFIngestionService.process_file(request.file_path)
        
        metadata = {
            "subject_id": request.subject_id,
            "filename": request.filename,
            "source": request.file_path,
            "user_id": uid
        }
        
        if vector_store:
            vector_store.add_document(text, metadata)
            
            try:
                from app.services.flashcards import FlashcardService
                fc_service = FlashcardService()
                await fc_service.generate_and_save(
                    uid=uid,
                    subject_id=request.subject_id,
                    text_content=text,
                    file_id=request.filename, 
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
async def delete_file(request: DeleteRequest, user: dict = Depends(get_current_user)):
    try:
        if vector_store:
            vector_store.delete_document(user['uid'], request.filename)
            return {"status": "success", "message": f"Deleted {request.filename}"}
        else:
            raise HTTPException(status_code=500, detail="Vector Store not initialized")
    except Exception as e:
        print(f"Error deleting file: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/chat")
async def chat(request: ChatRequest, user: dict = Depends(get_current_user)):
    try:
        if not vector_store or not chat_service:
            raise HTTPException(status_code=500, detail="Services not initialized")
            

        context_docs = vector_store.similarity_search_with_retry(
            request.query, 
            user_id=user['uid'], 
            subject_id=None, 
            k=10
        )
        
        answer, event_data = chat_service.get_answer(
            query=request.query, 
            context_docs=context_docs, 
            history=request.history,
            image_base64=request.image_base64
        )
        
        return {
            "answer": answer,
            "sources": [doc.metadata.get("filename") for doc in context_docs],
            "event_data": event_data
        }
    except Exception as e:
        print(f"Error generating answer: {e}")
        raise HTTPException(status_code=500, detail=str(e))

from app.routers import flashcards, quiz
app.include_router(flashcards.router, prefix="/flashcards", tags=["flashcards"])
app.include_router(quiz.router, prefix="/quiz", tags=["quiz"])

from app.services.study_plan import StudyPlanService, StudyPlanResponse

class StudyPlanRequest(BaseModel):
    file_path: str
    subject_id: str
    section: Optional[str] = None

@app.post("/study-plan/generate", response_model=StudyPlanResponse)
async def generate_study_plan(request: StudyPlanRequest, user: dict = Depends(get_current_user)):
    try:
        uid = user['uid']
        # 1. Extract Text
        text = PDFIngestionService.process_file(request.file_path)
        
        # 2. Generate Plan
        service = StudyPlanService()
        plan = await service.generate_plan(text, section=request.section)
        
        # 3. Return the plan directly so the mobile app can show a Setup UI
        return plan
            
    except Exception as e:
        print(f"Error generating study plan: {e}")
        raise HTTPException(status_code=500, detail=str(e))

from firebase_admin import auth as firebase_auth

@app.delete("/admin/users/{uid}")
async def delete_admin_user(uid: str, user: dict = Depends(get_current_user)):
    try:
        # Delete user from Firebase Auth
        firebase_auth.delete_user(uid)
        
        # Delete user from Firestore
        db = firestore.Client()
        db.collection('users').document(uid).delete()
        
        return {"status": "success", "message": f"User {uid} deleted successfully"}
    except Exception as e:
        print(f"Error deleting user {uid}: {e}")
        raise HTTPException(status_code=500, detail=str(e))
