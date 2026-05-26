from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import json
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import HumanMessage

class StudyPlanEvent(BaseModel):
    title: str
    date: str # ISO 8601 YYYY-MM-DDTHH:MM:SS
    type: str # "Class" or "Exam" or "Assignment" or "Quiz" or "Project"
    description: Optional[str] = None

class StudyPlanResponse(BaseModel):
    events: List[StudyPlanEvent]
    bloom_levels: List[str] = []

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

    async def generate_plan(self, text_content: str, section: Optional[str] = None) -> StudyPlanResponse:
        section_prompt = f"\n\nCRITICAL TARGET SECTION: '{section}'\nPAY EXTREMELY CLOSE ATTENTION to any timetables, class timings, or recurring periods mentioned for Section '{section}'.\nYou MUST prioritize finding BOTH the MAIN LECTURE timings (which may apply to all sections or a parent section) AND the specific LAB/TUTORIAL timings for Section '{section}'.\nCRITICAL: You MUST extract exactly ONE event of type 'Class' representing the FIRST occurrence of the MAIN LECTURE, and exactly ONE event of type 'Class' representing the FIRST occurrence of the LAB/TUTORIAL for Section '{section}'. DO NOT output multiple recurrent versions of the same Class.\nIf a class has both a Lecture and a Lab, you should output TWO 'Class' events.\nFurthermore, all 'Exam', 'Assignment', 'Quiz', and 'Project' events MUST have their embedded hour and minute set to the exact same hour/minute as the designated Lecture time, if no explicit time is given." if section else "\nYou MUST extract exactly ONE event of type 'Class' representing the FIRST occurrence of the MAIN LECTURE. DO NOT output multiple recurrent versions of the same Class.\nFurthermore, all 'Exam', 'Assignment', 'Quiz', and 'Project' events MUST have their time set to the exact same hour and minute as the designated Lecture time, if no explicit time is given."

        prompt = f"""
        You are an intelligent study assistant. Your task is to analyze the following document content (typically a syllabus or course outline) and extract key dates, exams, assignments, quizzes, projects, and Class schedules.
        {section_prompt}
        
        Additionally, you MUST review the text for Course Outcomes or Learning Objectives. Map the verbs found in these outcomes to the following specific Bloom's Taxonomy levels:
        - KNOWLEDGE (e.g., List, Name, Recall, Record, Relate, Repeat, State, Tell, Underline, Describe, Discuss)
        - COMPREHENSION (e.g., Compare, Describe, Discuss, Explain, Express, Identify, Recognize, Restate, Tell, Translate)
        - APPLICATION (e.g., Apply, Complete, Construct, Demonstrate, Dramatize, Employ, Illustrate, Interpret, Operate, Practice, Schedule, Sketch, Use)
        - ANALYSIS (e.g., Analyze, Appraise, Categorize, Compare, Contrast, Debate, Diagram, Differentiate, Distinguish, Examine, Experiment, Inspect, Inventory, Question, Test)
        - SYNTHESIS (e.g., Arrange, Assemble, Collect, Combine, Comply, Compose, Construct, Create, Design, Devise, Formulate, Manage, Organize, Plan, Prepare, Propose, Setup)
        - EVALUATION (e.g., Appraise, Argue, Assess, Choose, Compare, Conclude, Estimate, Evaluate, Interpret, Judge, Justify, Measure, Rate, Revise, Score, Select, Support, Value)

        Output STRICTLY in JSON format without markdown ticks, with two main fields: 'events' and 'bloom_levels'. 
        
        Example JSON structure:
        {{
            "events": [
                {{
                    "title": "Class: Chapter 1",
                    "date": "2023-10-15T10:00:00",
                    "type": "Class"
                }}
            ],
            "bloom_levels": ["Knowledge", "Analysis", "Application"]
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
            bloom_levels = data.get("bloom_levels", [])
            print(f"Parsed events: {len(events)}, Bloom levels: {bloom_levels}")
            return StudyPlanResponse(events=events, bloom_levels=bloom_levels)
        except Exception as e:
            print(f"Error parsing study plan JSON: {e}")
            print(f"Raw content: {content}")
            return StudyPlanResponse(events=[])
