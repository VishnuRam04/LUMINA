from typing import List, Optional
import json
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import PromptTemplate
from app.core.config import settings
from app.services.vector_store import VectorStoreService
from app.models.quiz import QuizQuestion, QuestionType, GradeResponse
from google.cloud.firestore_v1.base_query import FieldFilter, And

class QuizService:
    def __init__(self):
        self.llm = ChatGoogleGenerativeAI(
            model="gemini-2.5-pro",
            google_api_key=settings.GOOGLE_API_KEY,
            temperature=0.7
        )
        self.vector_store = VectorStoreService()

    async def generate_quiz(self, uid: str, subject_id: str, file_ids: List[str], count: int, bloom_levels: List[str] = []) -> List[QuizQuestion]:
        context_docs = []
        
        for file_id in file_ids:
            try:
                docs = self.vector_store.db.collection(self.vector_store.collection_name)\
                    .where(filter=FieldFilter("metadata.user_id", "==", uid))\
                    .where(filter=FieldFilter("metadata.subject_id", "==", subject_id))\
                    .where(filter=FieldFilter("metadata.filename", "==", file_id))\
                    .stream()
                
                for doc in docs:
                    data = doc.to_dict()
                    if 'content' in data:
                        context_docs.append(data['content'])
            except Exception as e:
                print(f"Error fetching docs for {file_id}: {e}")
        
        seen = set()
        unique_docs = []
        for text in context_docs:
            if text not in seen:
                seen.add(text)
                unique_docs.append(text)
        
        context_text = "\n\n".join(unique_docs)
        
        prompt = PromptTemplate(
            template="""
            You are an expert exam setter. Create a quiz based STRICTLY on the following context.
            
            Context:
            {context}
            
            **Requirements:**
            1. Create {count} questions.
            2. Mix Question Types: 70% Multiple Choice (MCQ), 30% Open Ended.
            3. Follow Bloom's Taxonomy: Focus the questions heavily on the specific cognitive levels required: {bloom_levels}. Structure the questions around these cognitive tasks.
            4. CRITICAL: Formulate the questions to be 100% self-contained. NEVER use phrases like "based on the context", "in the provided text", or "on page X". The test-taker will not be looking at the notes when they answer.
            5. Format EXACTLY as a JSON list of objects.
            
            **JSON Structure for MCQ:**
            {{
                "type": "multiple_choice",
                "question": "Question text...",
                "options": ["Option A", "Option B", "Option C", "Option D"],
                "correct_answer": "Option A", 
                "explanation": "Why A is correct..."
            }}
            
            **JSON Structure for Open Ended:**
            {{
                "type": "open_ended",
                "question": "Question text...",
                "explanation": "Key points that must be in the answer..."
            }}
            
            Return ONLY the valid JSON list. do not use markdown code blocks.
            """,
            input_variables=["context", "count", "bloom_levels"]
        )
        
        bloom_val = ", ".join(bloom_levels) if bloom_levels else "Progressively structured: remember/understand -> application -> analyze/evaluate (default)"
        
        chain = prompt | self.llm
        response = await chain.ainvoke({
            "context": context_text,
            "count": count,
            "bloom_levels": bloom_val
        })
        
        content = response.content.replace("```json", "").replace("```", "").strip()
        try:
            raw_data = json.loads(content)
            questions = []
            for item in raw_data:
                q = QuizQuestion(
                    type=QuestionType(item["type"]),
                    question=item["question"],
                    options=item.get("options"),
                    correct_answer=item.get("correct_answer"),
                    explanation=item["explanation"]
                )
                questions.append(q)
            return questions
        except Exception as e:
            print(f"JSON Parsing Error: {e}")
            print(f"Raw Content: {content}")
            return []

    async def grade_open_ended(self, question: str, user_answer: str, context: str = "") -> GradeResponse:
        prompt = PromptTemplate(
            template="""
            You are a strict but helpful professor grading a student's answer.
            
            Question: {question}
            Student Answer: {user_answer}
            Context/Reference Info: {context}
            
            Evaluate the answer.
            1. Is it correct? (True/False). Partial credit counts as True if main point is hit.
            2. Score (0-100).
            3. Detailed Feedback.
            4. Tip for improvement.
            
            Return JSON:
            {{
                "is_correct": true,
                "score": 85,
                "feedback": "...",
                "improvement_tip": "..."
            }}
            """,
            input_variables=["question", "user_answer", "context"]
        )
        
        chain = prompt | self.llm
        response = await chain.ainvoke({
            "question": question,
            "user_answer": user_answer,
            "context": context
        })
        
        content = response.content.replace("```json", "").replace("```", "").strip()
        data = json.loads(content)
        return GradeResponse(**data)
