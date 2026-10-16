# 🛡️ Deepfake Protection App

## 📌 Overview
딥페이크 악용을 방지하기 위해
이미지에 적대적 노이즈(Adversarial Noise)를 적용하여
사전적으로 보호하는 애플리케이션입니다.

---

## 🏗️ Architecture
- **Frontend** — iOS (Swift)
- **Backend** — Spring Boot (Java)
- **AI Server** — FastAPI (Python)

---

## 📁 Project Structure
```
deepfake-project/
├── app/              # iOS App (Swift)
├── server/
│   ├── api/          # Spring Boot Backend
│   └── ai_server/    # FastAPI AI Server
└── model/            # AI Model
```

---

## ⚙️ Tech Stack
| 분류 | 기술 |
|------|------|
| Frontend | Swift |
| Backend | Java, Spring Boot |
| AI | Python, FastAPI, PyTorch |
| DB | PostgreSQL |
| Infra | AWS (EC2, S3), Docker |

---

## 🚀 Features
- 이미지 업로드
- AI 기반 딥페이크 위험 분석
- 적대적 노이즈 적용
- 결과 이미지 비교 및 다운로드

---

## 🐳 Getting Started

### 사전 요구사항
- Docker Desktop 설치

### 실행 방법
```bash
git clone https://github.com/youngmin-OS/Capstone_HMM.git
cd Capstone_HMM
docker compose up --build
```

### 접속
| 서비스 | 주소 |
|--------|------|
| Spring Boot API | http://localhost:8080 |
| FastAPI AI Server | http://localhost:8000 |
| FastAPI 문서 | http://localhost:8000/docs |

---

## 🎯 Goal
딥페이크를 사전에 방지하여 개인 정보 보호 및 안전한 콘텐츠 환경을 제공합니다.
