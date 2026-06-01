import os
import sys
import tempfile

_BASE = os.environ.get(
    "PROJECT_ROOT",
    os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
)

# regressor.py 내부의 `from model import SixDRepNet` 와 `import utils` 가
# sixdrepnet/model.py, sixdrepnet/utils.py 를 찾도록 sixdrepnet/ 을 추가
_SIXDREPNET_DIR = os.path.join(_BASE, "model", "6DRepNet", "sixdrepnet")
# detect_face, head_pose 를 직접 import
_RISK_ANALYZER_DIR = os.path.join(_BASE, "model", "risk_analyzer")

for _p in [_SIXDREPNET_DIR, _RISK_ANALYZER_DIR]:
    if _p not in sys.path:
        sys.path.insert(0, _p)

# 프로젝트 루트를 sys.path 에 넣으면 'model' 패키지 이름이 충돌하므로 직접 import
from detect_face import detect_face
from head_pose import get_head_pose


def _calculate_risk(face_ratio: float, yaw: float) -> dict:
    exposure  = min(face_ratio * 2.0, 1.0)          # 얼굴 비율 (0.5 이상이면 만점)
    frontal   = max(0.0, 1.0 - abs(yaw) / 90.0)     # 정면일수록 높음

    score = round(0.5 * exposure + 0.5 * frontal, 4)

    if score >= 0.7:
        level = "HIGH"
    elif score >= 0.4:
        level = "MEDIUM"
    else:
        level = "LOW"

    return {"score": score, "level": level}


def analyze_image(contents: bytes) -> dict:
    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
        tmp.write(contents)
        tmp_path = tmp.name

    try:
        detection = detect_face(tmp_path)
    finally:
        os.unlink(tmp_path)

    if detection is None:
        return {
            "overall_risk": 0,
            "risk_label": "LOW",
            "lpips_risk": 0.0,
            "clip_risk": 0.0,
            "arc_risk": 0.0,
        }

    face_crop, face_ratio = detection
    pose = get_head_pose(face_crop)

    yaw = round(float(pose[0]), 2) if pose else 0.0

    risk = _calculate_risk(float(face_ratio), yaw)

    return {
        "overall_risk": int(risk["score"] * 100),
        "risk_label": risk["level"],
        "lpips_risk": 0.0,
        "clip_risk": 0.0,
        "arc_risk": 0.0,
    }
