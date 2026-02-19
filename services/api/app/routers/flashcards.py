from datetime import datetime
from fastapi import APIRouter, HTTPException, Depends
from app.models.flashcard import Flashcard, FlashcardGenerationRequest, ReviewRequest, CreateCardRequest
from app.services.flashcards import FlashcardService
from app.dependencies.auth import get_current_user

router = APIRouter()
_service = None

def get_service():
    global _service
    if not _service:
        _service = FlashcardService()
    return _service

@router.post("/generate", response_model=list[Flashcard])
async def generate_flashcards(req: FlashcardGenerationRequest, user: dict = Depends(get_current_user)):
    service = get_service()
    cards = await service.generate_and_save(
        uid=user['uid'],
        subject_id=req.subject_id, 
        text_content=req.text_content, 
        file_id=req.file_id, 
        count=req.count
    )
    return cards

@router.get("/subject/{subject_id}", response_model=list[Flashcard])
def get_cards(subject_id: str, user: dict = Depends(get_current_user)):
    return get_service().get_cards_for_subject(user['uid'], subject_id)

@router.post("/create", response_model=Flashcard)
def create_card(req: CreateCardRequest, user: dict = Depends(get_current_user)):
    service = get_service()
    uid = user['uid']
    doc_ref = service.db.collection("users").document(uid).collection("flashcards").document()
    card = Flashcard(
        id=doc_ref.id,
        subject_id=req.subject_id,
        file_id=req.file_id,
        front=req.front,
        back=req.back,
        repetition=0,
        interval=0,
        ease_factor=2.5,
        next_review=datetime.now(),
        status='new'
    )
    doc_ref.set(card.model_dump())
    return card

@router.post("/review", response_model=Flashcard)
def review_card(req: ReviewRequest, user: dict = Depends(get_current_user)):
    try:
        updated = get_service().update_card_sm2(user['uid'], req.card_id, req.rating)
        return updated
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
