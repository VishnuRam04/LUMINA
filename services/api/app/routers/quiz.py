from fastapi import APIRouter, HTTPException, Depends
from app.models.quiz import Quiz, GenerateQuizRequest, GradeOpenEndedRequest, GradeResponse, QuizQuestion, UpdateQuizScoreRequest
from app.services.quiz_service import QuizService
from app.dependencies.auth import get_current_user
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
async def generate_quiz(req: GenerateQuizRequest, user: dict = Depends(get_current_user)):
    service = get_service()
    uid = user['uid']
    
    questions = await service.generate_quiz(
        uid=user['uid'],
        subject_id=req.subject_id,
        file_ids=req.file_ids,
        count=req.count,
        bloom_levels=req.bloom_levels
    )
    
    if not questions:
        raise HTTPException(status_code=500, detail="Failed to generate quiz questions")
    
    quiz = Quiz(
        id=str(uuid.uuid4()),
        subject_id=req.subject_id,
        title=f"Quiz - {datetime.now().strftime('%b %d, %H:%M')}", 
        file_ids=req.file_ids,
        questions=questions,
        created_at=datetime.now()
    )
    
    db = service.vector_store.db
    db.collection("users").document(uid).collection("quizzes").document(quiz.id).set(quiz.model_dump())
    
    return quiz

@router.get("/list/{subject_id}", response_model=list[Quiz])
def list_quizzes(subject_id: str, user: dict = Depends(get_current_user)):
    service = get_service()
    uid = user['uid']
    db = service.vector_store.db
    
    # Query: users/{uid}/quizzes where subject_id == ...
    docs = db.collection("users").document(uid).collection("quizzes")\
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

@router.delete("/delete/{quiz_id}")
async def delete_quiz(quiz_id: str, user: dict = Depends(get_current_user)):
    service = get_service()
    uid = user['uid']
    db = service.vector_store.db
    try:
        # Path: users/{uid}/quizzes/{quiz_id}
        db.collection("users").document(uid).collection("quizzes").document(quiz_id).delete()
        return {"status": "success", "message": f"Quiz {quiz_id} deleted"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/grade", response_model=GradeResponse)
async def grade_answer(req: GradeOpenEndedRequest, user: dict = Depends(get_current_user)):
    service = get_service()
    # Grading is stateless but we require auth
    result = await service.grade_open_ended(req.question, req.user_answer, req.context or "")
    return result

@router.post("/score/{quiz_id}")
async def update_quiz_score(quiz_id: str, req: UpdateQuizScoreRequest, user: dict = Depends(get_current_user)):
    service = get_service()
    uid = user['uid']
    db = service.vector_store.db
    
    doc_ref = db.collection("users").document(uid).collection("quizzes").document(quiz_id)
    doc = doc_ref.get()
    
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Quiz not found")
        
    try:
        # Atomic increment of attempts and update of last_score
        doc_ref.update({
            "last_score": req.score,
            "attempts": firestore.Increment(1)
        })
        return {"status": "success", "message": "Score updated"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
