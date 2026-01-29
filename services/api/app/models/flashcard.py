from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime, timedelta

class Flashcard(BaseModel):
    id: Optional[str] = None
    subject_id: str
    file_id: Optional[str] = None
    front: str
    back: str
    
    # SM-2 Parameters
    repetition: int = 0
    interval: int = 0
    ease_factor: float = 2.5
    next_review: datetime = Field(default_factory=datetime.now)
    
    # Status
    status: str = "new" # new, learning, mastered (derived from interval/repetition)
    
    class Config:
        populate_by_name = True
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class FlashcardGenerationRequest(BaseModel):
    subject_id: str
    file_id: Optional[str] = None
    text_content: str
    count: int = 10

class CreateCardRequest(BaseModel):
    subject_id: str
    file_id: Optional[str] = None
    front: str
    back: str

class ReviewRequest(BaseModel):
    card_id: str
    rating: int # 1 (Need Review) - 5 (Easy/Got it)
