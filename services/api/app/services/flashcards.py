import json
from datetime import datetime, timedelta
from google.cloud import firestore
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import HumanMessage, SystemMessage
from app.core.config import settings
from app.models.flashcard import Flashcard

class FlashcardService:
    def __init__(self):
        self.db = firestore.Client()
        self.llm = ChatGoogleGenerativeAI(
            model="gemini-2.0-flash", 
            google_api_key=settings.GOOGLE_API_KEY,
            temperature=0.3, 
            convert_system_message_to_human=True
        )
    async def generate_and_save(self, uid: str, subject_id: str, text_content: str, file_id: str = None, count: int = 10) -> list[Flashcard]:
        """
        Generates flashcards from text using LLM and saves to Firestore under the user.
        """
        prompt = f"""
        You are an expert tutor. Create {count} high-quality flashcards based on the following text.
        
        **Rules:**
        1. **Front**: A clear question or concept.
        2. **Back**: A concise but complete answer.
        3. **Focus**: Key definitions, formulas, dates, and core concepts.
        4. **CRITICAL**: Make questions entirely self-contained. NEVER use phrases like "based on the text", "in the provided document", or "as described".
        5. **Output**: Return a RAW JSON List of objects. NO Markdown.
        
        Example format:
        [
            {{"front": "What is ...?", "back": "It is ..."}},
            {{"front": "Formula for ...", "back": "E = mc^2"}}
        ]
        
        Text Content:
        {text_content}
        """
        
        try:
            response = self.llm.invoke([
                SystemMessage(content="You are a JSON-generating AI. Output ONLY valid JSON array."),
                HumanMessage(content=prompt)
            ])
            
            content = response.content.strip()
            if content.startswith("```"):
                content = content.split("\n", 1)[1]
                content = content.rsplit("```", 1)[0]
                
            card_data_list = json.loads(content)
            
            created_cards = []
            
            batch = self.db.batch()
            col_ref = self.db.collection("users").document(uid).collection("flashcards")
            
            for item in card_data_list:
                doc_ref = col_ref.document()
                card = Flashcard(
                    id=doc_ref.id,
                    subject_id=subject_id,
                    file_id=file_id,
                    front=item['front'],
                    back=item['back'],
                    repetition=0,
                    interval=0,
                    ease_factor=2.5,
                    next_review=datetime.now(),
                    status='new'
                )
                batch.set(doc_ref, card.model_dump())
                created_cards.append(card)
                
            batch.commit()
            print(f"Generated and saved {len(created_cards)} flashcards for {subject_id}")
            return created_cards
            
        except Exception as e:
            print(f"Error generating flashcards: {e}")
            return []

    def get_cards_for_subject(self, uid: str, subject_id: str):
        docs = self.db.collection("users").document(uid).collection("flashcards") \
            .where("subject_id", "==", subject_id).stream()
        return [Flashcard(**d.to_dict()) for d in docs]
    
    def get_cards_due(self, uid: str, subject_id: str):
        now = datetime.now()
        all_cards = self.get_cards_for_subject(uid, subject_id)
        return [c for c in all_cards if c.next_review <= now]

    def update_card_sm2(self, uid: str, card_id: str, quality: int):
        """
        Updates a card's schedule using the SM-2 algorithm.
        quality: 0-5
        """
        doc_ref = self.db.collection("users").document(uid).collection("flashcards").document(card_id)
        snap = doc_ref.get()
        if not snap.exists:
            raise ValueError("Card not found")
        
        data = snap.to_dict()
        card = Flashcard(**data)
        
        if quality >= 3:
            if card.repetition == 0:
                card.interval = 1
            elif card.repetition == 1:
                card.interval = 6
            else:
                card.interval = int(card.interval * card.ease_factor)
            
            card.repetition += 1
            card.status = "mastered" if card.interval > 21 else "learning"
        else:
            card.repetition = 0
            card.interval = 1
            card.status = "learning"
        
        card.ease_factor = card.ease_factor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
        if card.ease_factor < 1.3:
            card.ease_factor = 1.3
            
        card.next_review = datetime.now() + timedelta(days=card.interval)
        
        doc_ref.set(card.model_dump())
        return card
