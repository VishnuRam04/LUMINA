import google.generativeai as genai
from app.core.config import settings

genai.configure(api_key=settings.GOOGLE_API_KEY)

model_name = "models/gemini-embedding-001"
text = "Hello world"

try:
    result = genai.embed_content(
        model=model_name,
        content=text,
        task_type="retrieval_document",
        output_dimensionality=768
    )
    embedding = result['embedding']
    print(f"Model: {model_name}")
    print(f"Dimension: {len(embedding)}")
except Exception as e:
    print(f"Error: {e}")
