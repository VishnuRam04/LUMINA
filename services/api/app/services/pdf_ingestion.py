import io
from pypdf import PdfReader
from app.core.firebase import get_storage_bucket

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
    def extract_text(pdf_stream: io.BytesIO) -> str:
        reader = PdfReader(pdf_stream)
        text = ""
        for page in reader.pages:
            text += page.extract_text() + "\n"
        return text

    @classmethod
    def process_file(cls, storage_path: str) -> str:
        print(f"Downloading {storage_path}...")
        stream = cls.download_blob_to_stream(storage_path)
        print("Extracting text...")
        return cls.extract_text(stream)
