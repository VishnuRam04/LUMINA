from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import PromptTemplate

from app.core.config import settings

class ChatGenService:
    def __init__(self):
        self.llm = ChatGoogleGenerativeAI(
            model="gemini-2.5-pro",
            google_api_key=settings.GOOGLE_API_KEY,
            temperature=0.7
        )
        
        self.prompt_template = PromptTemplate(
            template="""
            You are Lumina, a friendly and intelligent study tutor.
            
            **Guidelines:**
            1. **Friendly Tone**: Be encouraging and clear.
            2. **Format**: 
               - Use **Standard Markdown Table** syntax for comparisons.
               - **NO Markdown inside Table Cells**: Do NOT use bold (**), italics (*), or code ticks (`) INSIDE table cells. Keep cell content plain text for better readability.
               - **DO NOT** wrap the table in a code block.
            3. **Knowledge Source**: 
               - Use the "Context" first.
               - **Fallback Allowed**: If the context doesn't have the answer, YOU ARE ALLOWED to answer using your own knowledge. Just state clearly that it is general info.
            
            **Context Usage:**
            - If from context: "Source: [Filename]" at the end.
            - If from general knowledge: "Source: General Knowledge" at the end.
            
            Context:
            {context}
            
            Chat History:
            {chat_history}
            
            Question: {question}
            
            Answer:
            """,
            input_variables=["context", "chat_history", "question"]
        )

    def get_answer(self, query: str, context_docs: list, history: list = []) -> str:
        # Simple RAG: Concatenate docs and prompt
        # We now include the filename in the context text so the LLM can cite it.
        context_text = "\n\n".join([
            f"[Source: {doc.metadata.get('filename') or doc.metadata.get('source', 'Unknown File')}]\n{doc.page_content}" 
            for doc in context_docs
        ])
        
        # Format history
        history_text = ""
        for msg in history:
            role = "User" if msg['role'] == 'user' else "Lumina"
            history_text += f"{role}: {msg['content']}\n"
        
        chain = self.prompt_template | self.llm
        response = chain.invoke({
            "context": context_text, 
            "chat_history": history_text,
            "question": query
        })
        
        # Clean response: Remove triple backticks around tables if present
        cleaned_content = response.content
        
        # Remove any starting/ending code blocks aggressively
        # Regex to strip ```markdown ... ``` or just ``` ... ```
        import re
        cleaned_content = re.sub(r"^```\w*\n", "", cleaned_content) # Start block
        cleaned_content = re.sub(r"\n```$", "", cleaned_content)     # End block
        cleaned_content = cleaned_content.replace("```", "")         # Stray backticks
        
        return cleaned_content.strip()
