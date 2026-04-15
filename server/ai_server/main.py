from fastapi import FastAPI, UploadFile, File, HTTPException
import os
import uuid

app = FastAPI()

UPLOAD_DIR = "uploads"
PROTECTED_DIR = "protected"

os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(PROTECTED_DIR, exist_ok=True)

ALLOWED_TYPES = ["image/jpeg", "image/png"]


@app.get("/")
def status():
    return {"status": "AI Server Running"}


@app.post("/upload")
async def upload(file: UploadFile = File(...)):
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail="이미지 파일만 업로드 가능합니다."
        )

    contents = await file.read()

    filename = f"{uuid.uuid4()}_{file.filename}"
    filepath = os.path.join(UPLOAD_DIR, filename)

    with open(filepath, "wb") as f:
        f.write(contents)

    return {
        "message": "업로드 성공",
        "filename": filename,
        "size": len(contents),
        "path": filepath
    }


@app.post("/analyze")
async def analyze(file: UploadFile = File(...)):
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail="이미지 파일만 업로드 가능합니다."
        )

    return {
        "result": "deepfake",
        "confidence": 0.87,
        "message": "딥페이크 의심 이미지입니다."
    }


@app.post("/protect")
async def protect(file: UploadFile = File(...)):
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail="이미지 파일만 업로드 가능합니다."
        )

    contents = await file.read()

    protected_filename = f"protected_{uuid.uuid4()}_{file.filename}"
    protected_path = os.path.join(PROTECTED_DIR, protected_filename)

    ## protected_img = faceshield.process(contents)
    # TODO: FaceShield 처리 결과 저장 예정
    with open(protected_path, "wb") as f:
        f.write(contents)

    return {
        "message": "이미지 보호 처리 완료",
        "protected_image_url": protected_path
    }