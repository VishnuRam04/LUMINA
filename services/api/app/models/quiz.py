from pydantic import BaseModel, Field
from typing import List, Optional
from enum import Enum
from datetime import datetime
import uuid

class QuestionType(str, Enum):
    MCQ = "multiple_choice"
    OPEN = "open_ended"

class QuizQuestion(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    type: QuestionType
    question: str
    options: Optional[List[str]] = None 
    correct_answer: Optional[str] = None 
    explanation: str  
    
class Quiz(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    subject_id: str
    title: str
    file_ids: List[str] = [] 
    questions: List[QuizQuestion]
    created_at: datetime = Field(default_factory=datetime.now)
    last_score: Optional[float] = None
    attempts: int = 0

class GenerateQuizRequest(BaseModel):
    subject_id: str
    file_ids: List[str] 
    count: int = 10
    bloom_levels: List[str] = []

class GradeOpenEndedRequest(BaseModel):
    question: str
    user_answer: str
    context: Optional[str] = None 

class GradeResponse(BaseModel):
    is_correct: bool
    score: int 
    feedback: str
    improvement_tip: str

class UpdateQuizScoreRequest(BaseModel):
    score: float
