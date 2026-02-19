from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import json
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import HumanMessage

class StudyPlanEvent(BaseModel):
    title: str
    date: str # ISO 8601 YYYY-MM-DD
    type: str # "exam", "assignment", "study_session"
    description: Optional[str] = None

class StudyPlanResponse(BaseModel):
    events: List[StudyPlanEvent]

class StudyPlanService:
    def __init__(self):
        from app.core.config import settings
        if not settings.GOOGLE_API_KEY:
            raise ValueError("GOOGLE_API_KEY is missing")
        
        self.llm = ChatGoogleGenerativeAI(
            model="gemini-2.0-flash",
            google_api_key=settings.GOOGLE_API_KEY,
            temperature=0.1
        )

    async def generate_plan(self, text_content: str) -> StudyPlanResponse:
        prompt = f"""
        You are an intelligent study assistant. Your task is to analyze the following document content (typically a syllabus or course outline) and extract key dates, exams, assignments, and suggest study milestones.
        
        Output strictly in JSON format with the following structure:
        {{
            "events": [
                {{
                    "title": "Midterm Exam",
                    "date": "2023-10-15",
                    "type": "exam"
                }}
            ]
        }}
        
        Today is {datetime.now().strftime('%Y-%m-%d')}.
        
        Document Content:
        {text_content[:20000]} 
        # Truncated to avoid context limits if very large, but 20k chars is plenty for syllabus
        """
        
        response = self.llm.invoke([HumanMessage(content=prompt)])
        
        content = response.content
        # Simple cleanup for JSON markdown
        if "```json" in content:
            content = content.replace("```json", "").replace("```", "")
        
        try:
            data = json.loads(content)
            events = [StudyPlanEvent(**e) for e in data.get("events", [])]
            print(f"Parsed events: {events}")
            return StudyPlanResponse(events=events)
        except Exception as e:
            print(f"Error parsing study plan JSON: {e}")
            print(f"Raw content: {content}")
            return StudyPlanResponse(events=[])
