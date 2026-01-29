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
    options: Optional[List[str]] = None  # For MCQ
    correct_answer: Optional[str] = None # For MCQ, internal check
    explanation: str  # For MCQ feedback
    
class Quiz(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    subject_id: str
    title: str
    file_ids: List[str] = [] # Chapters covered
    questions: List[QuizQuestion]
    created_at: datetime = Field(default_factory=datetime.now)

class GenerateQuizRequest(BaseModel):
    subject_id: str
    file_ids: List[str] # Selected chapters
    difficulty: str = "Medium"
    count: int = 10

class GradeOpenEndedRequest(BaseModel):
    question: str
    user_answer: str
    context: Optional[str] = None # Could pass RAG context or let backend fetch

class GradeResponse(BaseModel):
    is_correct: bool
    score: int # 0-100
    feedback: str
    improvement_tip: str
