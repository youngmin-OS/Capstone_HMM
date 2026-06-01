# 프로젝트 루트에서 빌드: docker build -f server/ai_server/Dockerfile -t ai-server .
FROM pytorch/pytorch:2.1.2-cuda11.8-cudnn8-runtime

WORKDIR /app

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        libgl1-mesa-glx \
        libglib2.0-0 \
        cmake \
        build-essential \
        libboost-python-dev \
        libboost-system-dev \
        libboost-filesystem-dev \
        libboost-graph-dev \
        libboost-regex-dev \
        liblapack-dev \
        libblas-dev \
        wget && \
    rm -rf /var/lib/apt/lists/*

# Python 패키지 설치
COPY server/ai_server/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# sixdrepnet 로컬 패키지 설치
COPY model/6DRepNet /app/model/6DRepNet
RUN pip install -e /app/model/6DRepNet

# 모델 코드 및 가중치
COPY model/risk_analyzer /app/model/risk_analyzer
COPY model/faceshield /app/model/faceshield
COPY weights /app/model/weights

# 서버 코드
COPY server/ai_server/app /app/app

RUN mkdir -p uploads protected model/faceshield/models

# 6DRepNet 모델 빌드 시점에 미리 다운로드 (컨테이너 시작 시 다운로드 방지)
RUN python -c "from sixdrepnet import SixDRepNet; SixDRepNet(gpu_id=-1)" 2>&1 | tail -5

# Risk Analyzer
ENV YOLO_WEIGHTS_PATH=/app/model/weights/yolov8n-face.pt
ENV PROJECT_ROOT=/app

# FaceShield 모델 경로
ENV FACESHIELD_DIR=/app/model/faceshield
ENV UNET_CONFIG=/app/model/faceshield/utils/unet/unet_config15.json
ENV IP_ADAPTER_PATH=/app/model/faceshield/models/ip-adapter_sd15.bin
ENV ARCFACE50_PATH=/app/model/faceshield/models/arcface_50.pth
ENV ARCFACE100_PATH=/app/model/faceshield/models/arcface_100.pth
ENV LANDMARK_PATH=/app/model/faceshield/models/shape_predictor_68_face_landmarks.dat

# HuggingFace 캐시 경로
ENV HF_HOME=/app/model/hf_cache
ENV TRANSFORMERS_CACHE=/app/model/hf_cache

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
