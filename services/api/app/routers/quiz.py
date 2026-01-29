from fastapi import APIRouter, HTTPException
from app.models.quiz import Quiz, GenerateQuizRequest, GradeOpenEndedRequest, GradeResponse, QuizQuestion
from app.services.quiz_service import QuizService
from google.cloud import firestore
import uuid
from datetime import datetime

router = APIRouter()
_service = None

def get_service():
    global _service
    if not _service:
        _service = QuizService()
    return _service

@router.post("/generate", response_model=Quiz)
async def generate_quiz(req: GenerateQuizRequest):
    service = get_service()
    
    # Generate Questions
    questions = await service.generate_quiz(
        subject_id=req.subject_id,
        file_ids=req.file_ids,
        count=req.count,
        difficulty=req.difficulty
    )
    
    if not questions:
        raise HTTPException(status_code=500, detail="Failed to generate quiz questions")
    
    # Create Quiz Object
    quiz = Quiz(
        id=str(uuid.uuid4()),
        subject_id=req.subject_id,
        title=f"Quiz - {datetime.now().strftime('%b %d, %H:%M')}", # Default title
        file_ids=req.file_ids,
        questions=questions,
        created_at=datetime.now()
    )
    
    # Save to Firestore (Reuse vector_store's db client or new one)
    # Using service.vector_store.db for convenience
    db = service.vector_store.db
    db.collection("quizzes").document(quiz.id).set(quiz.model_dump())
    
    return quiz

@router.get("/list/{subject_id}", response_model=list[Quiz])
def list_quizzes(subject_id: str):
    service = get_service()
    db = service.vector_store.db
    docs = db.collection("quizzes")\
             .where("subject_id", "==", subject_id)\
             .stream()
    
    quizzes = []
    for doc in docs:
        try:
            quizzes.append(Quiz(**doc.to_dict()))
        except Exception as e:
            print(f"Error parsing quiz {doc.id}: {e}")
            
    # Sort in memory to avoid Index requirement
    quizzes.sort(key=lambda x: x.created_at, reverse=True)
    return quizzes

@router.post("/grade", response_model=GradeResponse)
async def grade_answer(req: GradeOpenEndedRequest):
    service = get_service()
    result = await service.grade_open_ended(req.question, req.user_answer, req.context or "")
    return result
