import io
import fitz  # PyMuPDF
from pypdf import PdfReader
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import HumanMessage
from app.core.firebase import get_storage_bucket
from app.core.config import settings

class PDFIngestionService:
    @staticmethod
    def download_blob_to_stream(storage_path: str) -> io.BytesIO:
        bucket = get_storage_bucket()
        blob = bucket.blob(storage_path)
        
        byte_stream = io.BytesIO()
        blob.download_to_file(byte_stream)
        byte_stream.seek(0)
        return byte_stream

    @staticmethod
    def get_vision_description(image_bytes: bytes) -> str:
        """Sends image to Gemini Vision for description."""
        try:
            llm = ChatGoogleGenerativeAI(
                model="gemini-2.0-flash",
                google_api_key=settings.GOOGLE_API_KEY,
                temperature=0.2 # Low temp for factual description
            )
            
            # Correctly handle Base64 encoding
            import base64
            b64_image = base64.b64encode(image_bytes).decode('utf-8')
            
            message = HumanMessage(
                content=[
                    {"type": "text", "text": "This is a page from a student's notes. Transcribe all handwriting, text, and describe any diagrams, charts, or visual elements in detail. Structure the output clearly."},
                    {"type": "image_url", "image_url": f"data:image/jpeg;base64,{b64_image}"}
                ]
            )

            response = llm.invoke([message])
            return response.content
        except Exception as e:
            print(f"Vision API Error: {e}")
            return "[Error extracting visual content]"

    @classmethod
    def process_pdf_stream(cls, pdf_stream: io.BytesIO) -> str:
        """
        Iterates through PDF pages.
        - Tries text extraction.
        - If text is sparse (< 50 chars), assumes Image/Scan.
        - Uses Gemini Vision for images.
        """
        doc = fitz.open(stream=pdf_stream, filetype="pdf")
        full_text = ""
        
        print(f"Processing PDF with {len(doc)} pages...")
        
        for i, page in enumerate(doc):
            print(f"--- Page {i+1} ---")
            
            # 1. Try standard text extraction
            text = page.get_text()
            
            # 2. Heuristic check
            if len(text.strip()) < 50:
                print("  -> Low text detected. Using Gemini Vision...")
                try:
                    # Render page to image
                    pix = page.get_pixmap(matrix=fitz.Matrix(2, 2)) # 2x zoom for better quality
                    img_bytes = pix.tobytes("jpeg")
                    
                    description = cls.get_vision_description(img_bytes)
                    
                    text = f"\n[Page {i+1} Visual Content (Handwriting/Diagrams)]:\n{description}\n"
                    print("  -> Vision description generated.")
                except Exception as e:
                    print(f"  -> Error rendering/processing image: {e}")
                    text = f"\n[Page {i+1} Image Error]\n"
            else:
                print("  -> Text extracted successfully.")
            
            full_text += f"\n--- Page {i+1} ---\n{text}\n"
            
        return full_text



    @classmethod
    def process_file(cls, storage_path: str) -> str:
        print(f"Downloading {storage_path}...")
        stream = cls.download_blob_to_stream(storage_path)
        print("Extracting text...")
        return cls.process_pdf_stream(stream)
