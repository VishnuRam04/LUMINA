import os
import google.generativeai as genai
from app.core.config import settings

# Configure API key
genai.configure(api_key=settings.GOOGLE_API_KEY)

print("Listing available models...")
try:
    print("Models supporting EMBEDDINGS:")
    for m in genai.list_models():
        if 'embedContent' in m.supported_generation_methods:
            print(f"FOUND: {m.name}")
except Exception as e:
    print(f"Error listing models: {e}")
