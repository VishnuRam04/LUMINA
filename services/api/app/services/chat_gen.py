from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import PromptTemplate

from app.core.config import settings

class ChatGenService:
    def __init__(self):
        self.llm = ChatGoogleGenerativeAI(
            model="gemini-2.0-flash",
            google_api_key=settings.GOOGLE_API_KEY,
            temperature=0.7
        )
        
        self.prompt_template = PromptTemplate(
            template="""
            You are Lumina, a helpful AI study assistant.
            Use the following pieces of context to answer the question at the end.
            If you don't know the answer, just say that you don't know, don't try to make up an answer.
            
            Context:
            {context}
            
            Question: {question}
            
            Answer:
            """,
            input_variables=["context", "question"]
        )

    def get_answer(self, query: str, context_docs: list) -> str:
        # Simple RAG: Concatenate docs and prompt
        context_text = "\n\n".join([doc.page_content for doc in context_docs])
        
        chain = self.prompt_template | self.llm
        response = chain.invoke({"context": context_text, "question": query})
        
        return response.content
