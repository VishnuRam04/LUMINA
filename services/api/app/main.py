from fastapi import FastAPI
app = FastAPI(title="Lumina API")
@app.get("/health")
def health():
	return {"status":"ok"}
