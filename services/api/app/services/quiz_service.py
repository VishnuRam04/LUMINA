from typing import List, Optional
import json
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import PromptTemplate
from app.core.config import settings
from app.services.vector_store import VectorStoreService
from app.models.quiz import QuizQuestion, QuestionType, GradeResponse

class QuizService:
    def __init__(self):
        self.llm = ChatGoogleGenerativeAI(
            model="gemini-2.5-pro",
            google_api_key=settings.GOOGLE_API_KEY,
            temperature=0.7
        )
        self.vector_store = VectorStoreService()

    async def generate_quiz(self, subject_id: str, file_ids: List[str], count: int, difficulty: str) -> List[QuizQuestion]:
        # 1. Fetch Context
        # We query the vector store for each file to ensure we get relevant content from specific chapters
        context_docs = []
        queries = ["Important definitions", "Key concepts", "Summary", "Formulas and theorems"]
        
        for file_id in file_ids:
            # We try a few broad queries to get a good spread of content
            for q in queries:
                # Assuming vector_store has similarity_search with filter
                # We need to expose a method to filter by filename specifically, or use the kwargs
                # Using the existing similarity_search_with_retry but modifying filter logic momentarily
                # We will just pass filter dict directly if supported
                try:
                    # Direct access to vector_db query if possible, or use the wrapper
                    # The wrapper in vector_store.py needs update to support custom filter dict or we pass subject_id=None and manual filter
                    # Let's rely on the wrapper supporting kwargs or just instantiate a search
                    
                    # Workaround: The current wrapper takes subject_id. 
                    # We will bypass the wrapper's convenience method and call vector_db directly if needed
                    # but actually let's try to update VectorStoreService to be more flexible later.
                    # For now, let's try passing None for subject_id and hope we can somehow filter.
                    # Actually, let's just query by subject_id (which includes all files) and specific query term might bring relevant docs?
                    # No, that ignores the "Choose Chapter" constraint.
                    
                    # We will implement a helper in this service to fetch by file.
                    # FirestoreVectorStore supports filter={"metadata_field": "value"}
                    
                    docs = self.vector_store.vector_db.similarity_search(
                        q, 
                        k=3, 
                        filter={"filename": file_id} # This maps to metadata.filename == file_id
                    )
                    context_docs.extend(docs)
                except Exception as e:
                    print(f"Error fetching docs for {file_id}: {e}")
        
        # Deduplicate docs
        seen = set()
        unique_docs = []
        for doc in context_docs:
            if doc.page_content not in seen:
                seen.add(doc.page_content)
                unique_docs.append(doc)
        
        # Limit context size to avoid token limits (heuristic)
        context_text = "\n\n".join([d.page_content for d in unique_docs[:15]]) 
        
        # 2. Generate Questions
        prompt = PromptTemplate(
            template="""
            You are an expert exam setter. Create a quiz based STRICTLY on the following context.
            
            Context:
            {context}
            
            **Requirements:**
            1. Create {count} questions.
            2. Difficulty: {difficulty}.
            3. Mix Question Types: 70% Multiple Choice (MCQ), 30% Open Ended.
            4. Format EXACTLY as a JSON list of objects.
            
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
            input_variables=["context", "count", "difficulty"]
        )
        
        chain = prompt | self.llm
        response = await chain.ainvoke({
            "context": context_text,
            "count": count,
            "difficulty": difficulty
        })
        
        # Clean and Parse
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
