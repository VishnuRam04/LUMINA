from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import SystemMessage, HumanMessage
import re
import json
from app.core.config import settings

class ChatGenService:
    def __init__(self):
        self.llm = ChatGoogleGenerativeAI(
            model="gemini-2.5-pro",
            google_api_key=settings.GOOGLE_API_KEY,
            temperature=0.7
        )

    def get_answer(self, query: str, context_docs: list, history: list = [], image_base64: str = None) -> tuple[str, dict]:
        context_text = "\n\n".join([
            f"[Source: {doc.metadata.get('filename') or doc.metadata.get('source', 'Unknown File')}]\n{doc.page_content}" 
            for doc in context_docs
        ])
        
        history_text = ""
        for msg in history:
            role = "User" if msg['role'] == 'user' else "Lumina"
            history_text += f"{role}: {msg['content']}\n"
            
        system_prompt = f"""
You are Lumina, a friendly and intelligent study tutor.

**Guidelines:**
1. **Friendly Tone**: Be encouraging and clear.
2. **Analyze the Request**: 
   - If the user is just greeting you (e.g., "Hi", "Hello", "Help") or making small talk, **IGNORE THE CONTEXT** and respond naturally and politely.
   - If the user asks a question, check if the **Context** contains relevant information.
3. **Images & Visuals**:
   - The user can upload images! If an image is provided, thoroughly analyze its visual content to answer the user's questions (e.g., explaining diagrams, solving math problems, reading text, or summarizing notes).
4. **Format**: 
   - Use **Standard Markdown Table** syntax for comparisons.
   - **NO Markdown inside Table Cells**.
   - **DO NOT** wrap the table in a code block.
5. **Knowledge Source**: 
   - Use the "Context" first if it is relevant.
   - If from context: "Source: [Filename]" at the end.
   - If from general: "Source: General Knowledge" at the end.

6. **Event Extraction (CRITICAL)**:
   If the user uploads an image AND the image displays an event, homework deadline, exam date, or a schedule, you MUST extract the title and exact date. 
   At the absolute end of your entire response, append this exact markdown block so the app can schedule it:
   ```json
   {{"event_detected": true, "title": "Event Name", "date": "YYYY-MM-DDTHH:MM:SS"}}
   ```
"""

        user_content = [
            {"type": "text", "text": f"Context:\n{context_text}\n\nChat History:\n{history_text}\n\nQuestion: {query}\n\nAnswer:"}
        ]
        
        if image_base64:
            if image_base64.startswith("data:image"):
                img_data = image_base64
            else:
                img_data = f"data:image/jpeg;base64,{image_base64}"
            user_content.append({"type": "image_url", "image_url": {"url": img_data}})

        messages = [
            SystemMessage(content=system_prompt),
            HumanMessage(content=user_content)
        ]
        
        response = self.llm.invoke(messages)
        cleaned_content = response.content
        
        event_data = None
        event_match = re.search(r"```json\s*(\{.*?\})\s*```", cleaned_content, re.DOTALL)
        if event_match:
            try:
                parsed = json.loads(event_match.group(1))
                if parsed.get("event_detected") is True:
                    event_data = parsed
                    cleaned_content = cleaned_content.replace(event_match.group(0), "")
            except:
                pass

        cleaned_content = re.sub(r"^```\w*\n", "", cleaned_content.strip()) 
        cleaned_content = re.sub(r"\n```$", "", cleaned_content)            
        cleaned_content = cleaned_content.replace("```", "")                

        return cleaned_content.strip(), event_data
