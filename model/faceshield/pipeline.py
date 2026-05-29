"""
FaceShield+ 보호 처리 통합 진입점 (eps14_inner3 최종본)
백엔드에서 이거 하나만 import해서 쓰면 됨.

사용 예:
    from pipeline import protect_image, predict_risk

    # 1. 위험도 분석
    risk = predict_risk("/path/to/image.jpg")
    # → {'success': True, 'score': 65, 'level': 'MEDIUM', 'yaw': ..., 'pitch': ..., 'face_ratio': ...}

    # 2. 보호 처리 (다양한 입력 형식 지원)
    result = protect_image("/path/to/image.jpg")
    # 또는 bytes / numpy array / PIL Image
    print(result)
    # {
    #   "success": True,
    #   "protected_bytes": b"...",
    #   "metrics": {"px_diff": 2.5, ...},
    #   "error": None
    # }

핵심 기능:
- CNN 기반 image-specific target 예측 (ResNet18)
- Adaptive Lagrangian PGD with primal-dual λ update
- Multi-branch region weighting (inner/face/bg)
- LPIPS perceptual quality loss
- SAFETY + ONE_SIDED robustness mechanism
- Contrast-aware per-pixel noise clamp
- DCT low-pass filter, Gaussian smoothing
"""

import os
import io
import json
import datetime
import torch
import torch.nn.functional as F
import numpy as np
from PIL import Image
from omegaconf import OmegaConf
from tqdm import tqdm

# Transformers / Diffusers
from transformers import CLIPTokenizer, CLIPTextModel, CLIPVisionModelWithProjection
from diffusers import AutoencoderKL

# IP-Adapter
from utils.unet.ip_adapter.ip_adapter import ImageProjModel
from utils.unet.ip_adapter.utils import is_torch2_available

if is_torch2_available():
    from utils.unet.ip_adapter.attention_processor import (
        IPAttnProcessor2_0 as IPAttnProcessor,
        AttnProcessor2_0 as AttnProcessor,
    )
else:
    from utils.unet.ip_adapter.attention_processor import IPAttnProcessor, AttnProcessor

# Utility functions
from utils.utils import (
    get_loss_function,
    compute_vae_encodings,
    scale_tensor,
    create_line_mask,
    apply_gaussian,
    AttentionStore,
    compute_contrast_weight,
    generate_face_mask,
    resize_face3,
)

# Attack modules
from utils.unet.unet_attack import AttackUnet_IP_all, AttackCLIP
from utils.landmark.mtcnn_attack import mtcnn_attack
from utils.landmark.arcface_attack import AttackArcFace

# DCT tools
from utils.dct import dct_pass_filter, make_dct_basis, blockfy, encode, decode, deblockfy

# LPIPS (perceptual loss)
import lpips

# ============================================================
# 위험도 분석 — capstone_pipeline의 진짜 위험도 분석 사용
# ============================================================
import sys as _sys
try:
    import sys as _sys2
    _sys2.path.insert(0, '/workspace/capstone_pipeline/risk_analyzer')
    import importlib.util as _ilu

    _sdr_utils_spec = _ilu.spec_from_file_location(
        "_sdr_utils",
        "/workspace/capstone_pipeline/6DRepNet/sixdrepnet/utils.py"
    )
    _sdr_utils = _ilu.module_from_spec(_sdr_utils_spec)
    _sdr_utils_spec.loader.exec_module(_sdr_utils)
    import utils as _our_utils
    for _name in dir(_sdr_utils):
        if not _name.startswith('_') and not hasattr(_our_utils, _name):
            setattr(_our_utils, _name, getattr(_sdr_utils, _name))

    _spec = _ilu.spec_from_file_location(
        "capstone_risk",
        "/workspace/capstone_pipeline/risk_analyzer/pipeline.py"
    )
    _capstone_module = _ilu.module_from_spec(_spec)
    _spec.loader.exec_module(_capstone_module)
    _capstone_analyze_risk = _capstone_module.analyze_risk
    print('[FaceShield+] capstone_pipeline loaded (via importlib + 6DRepNet utils patch)')
except Exception as _e:
    print(f'[FaceShield+] WARN: capstone_pipeline import 실패 ({_e})')
    _capstone_analyze_risk = None



# ============================================================
# 1. 설정 (eps14_inner3 최종본)
# ============================================================
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# 모델 경로 (환경 변수로 오버라이드 가능)
MODEL_PATH = os.environ.get("MODEL_PATH", "runwayml/stable-diffusion-v1-5")
UNET_CONFIG = os.environ.get("UNET_CONFIG", "./utils/unet/unet_config15.json")
IP_ADAPTER_PATH = os.environ.get("IP_ADAPTER_PATH", "./utils/unet/ip_adapter/ip-adapter_sd15.bin")
IMAGE_ENCODER_PATH = os.environ.get("IMAGE_ENCODER_PATH", "h94/IP-Adapter")
ARCFACE50_PATH = os.environ.get("ARCFACE50_PATH", "./models/arcface50_checkpoint.tar")
ARCFACE100_PATH = os.environ.get("ARCFACE100_PATH", "./models/arcface100_checkpoint.tar")
LANDMARK_PATH = os.environ.get(
    "LANDMARK_PATH", "./shape_predictor_68_face_landmarks.dat"
)
CNN_PREDICTOR_PATH = os.environ.get("CNN_PREDICTOR_PATH", "./fs_predictor_model.pth")

# PGD 하이퍼파라미터 (eps14_inner3 최종 세팅)
PGD_CONFIG = {
    "total_iter": int(os.environ.get("TOTAL_ITER", 30)),
    "noise_clamp": float(os.environ.get("NOISE_CLAMP", 14)),  # ★ ε=14
    "step_size": 1.0,
    "resize_shape": 512,
    "attn_threshold": 0.2,
    "proj_func": "l1",
    "attn_func": "l2",
    "mtcnn_func": False,
    "arc_func": "cosine",
    # Multi-branch region weights (★ eps14_inner3)
    "lambda_inner": 3.0,   # 눈코입 (가장 강함)
    "lambda_face":  1.5,   # 얼굴 피부
    "lambda_bg":    1.0,   # 배경
    "dilation": 15,
    "blur_kernel": 5,
    "inner_dilation": 8,
    "inner_blur_kernel": 3,
    # Fixed α (보호 손실 비중)
    "alpha_mtcnn": float(os.environ.get("ALPHA_MTCNN", 9)),
    # Adaptive Lagrangian 설정 (★ 본 contribution)
    "adaptive": os.environ.get("ADAPTIVE", "true").lower() == "true",
    "safety_margin": float(os.environ.get("SAFETY_MARGIN", 0.85)),
    "one_sided": os.environ.get("ONE_SIDED", "true").lower() == "true",
    "eta_adaptive": float(os.environ.get("ETA_ADAPTIVE", 0.5)),
    "lambda_min": float(os.environ.get("LAMBDA_MIN", 0.1)),
    "lambda_init": float(os.environ.get("LAMBDA_INIT", 1.0)),
    "use_contrast": os.environ.get("USE_CONTRAST", "true").lower() == "true",
}


# ============================================================
# 2. 모델 로딩 (모듈 import 시 1번만)
# ============================================================
print("[FaceShield+] Loading models (eps14_inner3)...")

_config = OmegaConf.load(UNET_CONFIG)
_tokenizer = CLIPTokenizer.from_pretrained(MODEL_PATH, subfolder="tokenizer")
_text_encoder = CLIPTextModel.from_pretrained(MODEL_PATH, subfolder="text_encoder")
_vae = AutoencoderKL.from_pretrained(MODEL_PATH, subfolder="vae")
_unet = AttackUnet_IP_all.from_pretrained(
    MODEL_PATH, subfolder="unet", config_file=_config, strict=False
)
_image_preprocess = AttackCLIP()
_image_encoder = CLIPVisionModelWithProjection.from_pretrained(
    IMAGE_ENCODER_PATH, subfolder="models/image_encoder"
)
_face_embedder50 = torch.load(ARCFACE50_PATH, weights_only=False)
_face_embedder100 = torch.load(ARCFACE100_PATH, weights_only=False)
_id_preprocess = AttackArcFace()

_vae.requires_grad_(False).to(device)
_text_encoder.requires_grad_(False).to(device)
_image_encoder.requires_grad_(False).to(device)
_face_embedder50.requires_grad_(False).to(device)
_face_embedder100.requires_grad_(False).to(device)

# LPIPS (★ 화질 perceptual loss)
_lpips_fn = lpips.LPIPS(net='alex').to(device)
_lpips_fn.requires_grad_(False)
print("[FaceShield+] LPIPS loaded (net=alex)")

# IP-Adapter Image Projection Model
_image_proj_model = ImageProjModel(
    cross_attention_dim=_unet.config.cross_attention_dim,
    clip_embeddings_dim=_image_encoder.config.projection_dim,
    clip_extra_context_tokens=4,
).to(device)

# UNet Attention Processors
_attn_procs = {}
_unet_sd = _unet.state_dict()
for name in _unet.attn_processors.keys():
    cross_attention_dim = (
        None if name.endswith("attn1.processor") else _unet.config.cross_attention_dim
    )
    if name.startswith("down_blocks"):
        block_id = int(name[len("down_blocks.")])
        hidden_size = _unet.config.block_out_channels[block_id]
    elif name.startswith("mid_block"):
        hidden_size = _unet.config.block_out_channels[-1]
    elif name.startswith("up_blocks"):
        block_id = int(name[len("up_blocks.")])
        hidden_size = list(reversed(_unet.config.block_out_channels))[block_id]
    if cross_attention_dim is None:
        _attn_procs[name] = AttnProcessor()
    else:
        layer_name = name.split(".processor")[0]
        weights = {
            "to_k_ip.weight": _unet_sd[layer_name + ".to_k.weight"],
            "to_v_ip.weight": _unet_sd[layer_name + ".to_v.weight"],
        }
        _attn_procs[name] = IPAttnProcessor(
            hidden_size=hidden_size, cross_attention_dim=cross_attention_dim
        )
        _attn_procs[name].load_state_dict(weights)
_unet.set_attn_processor(_attn_procs)
_adapter_modules = torch.nn.ModuleList(_unet.attn_processors.values())

_state_dict = torch.load(IP_ADAPTER_PATH, map_location=device, weights_only=True)
_image_proj_model.load_state_dict(_state_dict["image_proj"], strict=True)
_adapter_modules.load_state_dict(_state_dict["ip_adapter"], strict=True)
_unet.requires_grad_(False).to(device)

# Text Encoder (empty prompt)
_inputs = _tokenizer(
    [""],
    max_length=_tokenizer.model_max_length,
    padding="max_length",
    truncation=True,
    return_tensors="pt",
)
_encoder_hidden_states = _text_encoder(_inputs.input_ids.to(device))[0]

# ============================================================
# 2-9. CNN Predictor (★ image-specific target 예측)
# ============================================================
_cnn_predictor = None

def _load_cnn():
    """CNN을 처음 호출 시 한 번 lazy load."""
    global _cnn_predictor
    if _cnn_predictor is not None:
        return _cnn_predictor
    try:
        from fs_predictor import FSReferencePredictor
        _cnn_predictor = FSReferencePredictor()
        _cnn_predictor.load_state_dict(
            torch.load(CNN_PREDICTOR_PATH, map_location=device, weights_only=True)["model_state_dict"]
        )
        _cnn_predictor.eval().to(device)
        _cnn_predictor.requires_grad_(False)
        print(f"[FaceShield+] CNN predictor loaded from {CNN_PREDICTOR_PATH}")
        return _cnn_predictor
    except Exception as e:
        print(f"[FaceShield+] WARN: CNN predictor 로드 실패 ({e}). Adaptive 모드 비활성화.")
        return None

print("[FaceShield+] Models loaded successfully.")


# ============================================================
# 3. 헬퍼 함수
# ============================================================
def _to_pil(image_input):
    """다양한 입력 형식 → PIL.Image (RGB)"""
    if isinstance(image_input, str):
        return Image.open(image_input).convert("RGB")
    if isinstance(image_input, (bytes, bytearray)):
        return Image.open(io.BytesIO(image_input)).convert("RGB")
    if isinstance(image_input, np.ndarray):
        return Image.fromarray(image_input).convert("RGB")
    if isinstance(image_input, Image.Image):
        return image_input.convert("RGB")
    if hasattr(image_input, "read"):
        return Image.open(image_input).convert("RGB")
    raise ValueError(f"Unsupported input type: {type(image_input)}")

def _pil_to_tensor(pil_img, size=512):
    """PIL → (1, 3, H, W) tensor [0, 1] range"""
    pil_img = pil_img.resize((size, size), Image.LANCZOS)
    arr = np.array(pil_img).astype(np.float32) / 255.0
    tensor = torch.from_numpy(arr).permute(2, 0, 1).contiguous().unsqueeze(0)
    return tensor.to(device)

def _tensor_to_bytes(tensor, format="PNG"):
    """(1, 3, H, W) tensor [0, 1] → PNG bytes"""
    arr = tensor.detach().squeeze(0).permute(1, 2, 0).cpu().numpy()
    arr = (np.clip(arr, 0, 1) * 255).astype(np.uint8)
    pil_img = Image.fromarray(arr)
    buf = io.BytesIO()
    pil_img.save(buf, format=format)
    return buf.getvalue()

def _compute_metrics(gt_face, protected):
    """간단한 메트릭 계산"""
    diff = (gt_face - protected).abs() * 255
    return {"px_diff": float(diff.mean().cpu())}


# ============================================================
# 4. CNN target 예측 (★ Adaptive 모드용)
# ============================================================
def _predict_target(gt_face):
    """
    CNN으로 이 이미지의 target metric 3개 예측.
    Args:
        gt_face: (1, 3, H, W) tensor [0, 1]
    Returns:
        dict {'lpips': float, 'clip_sim': float, 'arc_sim': float} 또는 None
    """
    cnn = _load_cnn()
    if cnn is None:
        return None
    # CNN 입력 형식 (224×224, normalized)
    from torchvision import transforms
    img_pil = Image.fromarray(
        (gt_face.squeeze(0).permute(1, 2, 0).cpu().numpy() * 255).astype(np.uint8)
    )
    tf = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])
    input_tensor = tf(img_pil).unsqueeze(0).to(device).float()
    with torch.no_grad():
        pred = cnn(input_tensor).cpu().numpy()[0]
    return {
        'lpips':    float(pred[0]),
        'clip_sim': float(pred[1]),
        'arc_sim':  float(pred[2]),
    }


# ============================================================
# 5. PGD 보호 처리 핵심 로직 (★ eps14_inner3 = Adaptive Lagrangian + 3-branch + LPIPS)
# ============================================================
def _run_pgd(gt_face):
    """
    eps14_inner3 PGD 보호 처리.
    Args:
        gt_face: (1, 3, H, W) tensor, [0, 1] range
    Returns:
        protected: (1, 3, H, W) tensor, [0, 1] range
    """
    # === 얼굴 마스크 + 눈코입 마스크 (★ 3-branch) ===
    face_mask, inner_mask = generate_face_mask(
        gt_face[0],
        LANDMARK_PATH,
        dilation=PGD_CONFIG["dilation"],
        blur_kernel=PGD_CONFIG["blur_kernel"],
        inner_dilation=PGD_CONFIG["inner_dilation"],
        inner_blur_kernel=PGD_CONFIG["inner_blur_kernel"],
    )
    
    # === Loss 함수 ===
    proj_func = get_loss_function(PGD_CONFIG["proj_func"])
    attn_func = get_loss_function(PGD_CONFIG["attn_func"])
    mtcnn_func = get_loss_function(PGD_CONFIG["mtcnn_func"])
    arc_func = get_loss_function(PGD_CONFIG["arc_func"])
    
    # === VAE Encoding ===
    latents_query = compute_vae_encodings(gt_face, _vae, device, gt=True)
    
    # === DCT 준비 ===
    N = 8
    DCT_basis = make_dct_basis(N, device)
    low_pass_filter, _ = dct_pass_filter(device)
    timestep = torch.tensor([0], device=device)
    
    # === ArcFace GT ===
    gt_50, gt_100 = _id_preprocess.preprocess(gt_face)
    gt_id_50 = _face_embedder50(gt_50.to(device))
    gt_id_100 = _face_embedder100(gt_100.to(device))
    
    # === UNet GT ===
    var_controller = AttentionStore()
    gt_preprocessed = _image_preprocess(gt_face)
    gt_encoded = _image_encoder(gt_preprocessed).image_embeds
    gt_proj = _image_proj_model(gt_encoded)
    stacked_encoder_hidden_states = torch.cat([_encoder_hidden_states, gt_proj], dim=1)
    _unet(
        latents_query, timestep, stacked_encoder_hidden_states,
        store_controller=var_controller,
        unet_threshold=PGD_CONFIG["attn_threshold"],
    )
    
    # === Adaptive λ 초기화 ===
    lam_lpips = PGD_CONFIG["lambda_init"]
    lam_clip  = PGD_CONFIG["lambda_init"]
    lam_arc   = PGD_CONFIG["lambda_init"]
    adaptive_target = None
    if PGD_CONFIG["adaptive"]:
        adaptive_target = _predict_target(gt_face)
        if adaptive_target is not None:
            print(f"[Adaptive] CNN target: {adaptive_target}")
        else:
            print("[Adaptive] target 예측 실패 → fixed mode")
    
    # === PGD 30 iter ===
    with torch.enable_grad():
        delta = torch.zeros_like(gt_face, requires_grad=True).to(device)
        
        # Contrast-aware
        if PGD_CONFIG["use_contrast"]:
            with torch.no_grad():
                contrast_weight = compute_contrast_weight(gt_face)
        else:
            contrast_weight = None
        
        for i in tqdm(range(PGD_CONFIG["total_iter"]), desc="[PGD]"):
            adv_face = (255 * gt_face) + delta
            adv_face = torch.clamp(adv_face, min=0, max=255)
            
            # MTCNN attack
            mtcnn_loss = 0
            mtcnn_loss = mtcnn_attack(
                2 * (adv_face / 255) - 1, loss_fn=mtcnn_func,
                loss=mtcnn_loss, device=device
            )
            
            # ArcFace Identity Attack
            adv_50, adv_100 = _id_preprocess.preprocess(adv_face / 255)
            adv_id_50 = _face_embedder50(adv_50)
            adv_id_100 = _face_embedder100(adv_100)
            id_loss_50 = arc_func(adv_id_50, gt_id_50)
            id_loss_100 = arc_func(adv_id_100, gt_id_100)
            id_loss = (-1) * id_loss_50 + (-1) * id_loss_100
            
            # Diff-Conditioned UNet Attack
            adv_preprocessed = _image_preprocess(adv_face / 255)
            adv_encoded = _image_encoder(adv_preprocessed).image_embeds
            adv_proj = _image_proj_model(adv_encoded)
            stacked_encoder_hidden_states = torch.cat(
                [_encoder_hidden_states, adv_proj], dim=1
            )
            clip_loss = proj_func(adv_encoded, gt_encoded)
            attn_loss = 0
            attn_loss = _unet(
                latents_query, timestep, stacked_encoder_hidden_states,
                loss_fn=attn_func, loss=attn_loss,
                gt_attn_map=var_controller.attn_map.copy(),
            )
            unet_loss = (-1) * clip_loss + (+1) * attn_loss
            
            # ★ LPIPS (perceptual quality loss)
            lpips_input_adv = 2 * (adv_face / 255) - 1
            lpips_input_gt = 2 * gt_face - 1
            lpips_loss = _lpips_fn(lpips_input_adv, lpips_input_gt).mean()
            
            # ★ Adaptive Lagrangian λ 자동 조정 (5 iter마다)
            if PGD_CONFIG["adaptive"] and adaptive_target is not None and i % 5 == 0:
                with torch.no_grad():
                    cur_arc   = F.cosine_similarity(adv_id_100, gt_id_100, dim=-1).mean().item()
                    cur_clip  = F.cosine_similarity(adv_encoded, gt_encoded, dim=-1).mean().item()
                    cur_lpips = lpips_loss.item()
                
                SAFETY = PGD_CONFIG["safety_margin"]
                ONE_SIDED = PGD_CONFIG["one_sided"]
                eta = PGD_CONFIG["eta_adaptive"]
                lam_min = PGD_CONFIG["lambda_min"]
                
                gap_lpips = cur_lpips - adaptive_target['lpips']    * SAFETY
                gap_clip  = cur_clip  - adaptive_target['clip_sim'] * SAFETY
                gap_arc   = cur_arc   - adaptive_target['arc_sim']  * SAFETY
                
                if ONE_SIDED:
                    gap_lpips = max(0, gap_lpips)
                    gap_clip  = max(0, gap_clip)
                    gap_arc   = max(0, gap_arc)
                
                lam_lpips = max(lam_min, lam_lpips + eta * gap_lpips)
                lam_clip  = max(lam_min, lam_clip  + eta * gap_clip)
                lam_arc   = max(lam_min, lam_arc   + eta * gap_arc)
            
            # Total loss
            if PGD_CONFIG["adaptive"] and adaptive_target is not None:
                total_loss = (
                    PGD_CONFIG["alpha_mtcnn"] * mtcnn_loss
                    + lam_arc   * id_loss
                    + lam_clip  * unet_loss
                    + lam_lpips * lpips_loss
                )
            else:
                # Fallback fixed-α
                alpha_id = float(os.environ.get("ALPHA_ID", 4))
                alpha_unet = float(os.environ.get("ALPHA_UNET", 1))
                alpha_lpips = float(os.environ.get("ALPHA_LPIPS", 0))
                total_loss = (
                    PGD_CONFIG["alpha_mtcnn"] * mtcnn_loss
                    + alpha_id * id_loss
                    + alpha_unet * unet_loss
                    + alpha_lpips * lpips_loss
                )
            
            total_loss.backward(retain_graph=True)
            
            # ★ Multi-branch 3단계 (눈코입 + 피부 + 배경)
            inner_area = inner_mask
            skin_area  = (face_mask - inner_mask).clamp(0, 1)
            bg_area    = 1 - face_mask
            region_weight = (
                PGD_CONFIG["lambda_inner"] * inner_area
                + PGD_CONFIG["lambda_face"]  * skin_area
                + PGD_CONFIG["lambda_bg"]    * bg_area
            )
            
            new_delta = PGD_CONFIG["step_size"] * torch.sign(delta.grad) * region_weight
            
            # Gaussian smoothing
            d_rgb = scale_tensor(new_delta)
            mask = create_line_mask(None, d_rgb)
            new_delta = apply_gaussian(None, new_delta, mask, 9, 5)
            
            # DCT low-pass
            delta.data -= new_delta
            grad_block, pad_size = blockfy(delta.data, N)
            grad_dct = encode(grad_block, DCT_basis)
            grad_dct_passed = grad_dct * low_pass_filter.expand(grad_dct.shape)
            grad_block_passed = decode(grad_dct_passed, DCT_basis)
            delta.data = deblockfy(grad_block_passed, pad_size)
            
            # Contrast-aware clamp
            if contrast_weight is not None:
                local_max = PGD_CONFIG["noise_clamp"] * contrast_weight
                delta.data = torch.clamp(delta.data, min=-local_max, max=local_max)
            else:
                delta.data = torch.clamp(
                    delta.data,
                    min=-PGD_CONFIG["noise_clamp"],
                    max=PGD_CONFIG["noise_clamp"],
                )
            
            # Final ε-ball
            delta.data = torch.clamp(
                delta.data,
                min=-PGD_CONFIG["noise_clamp"],
                max=PGD_CONFIG["noise_clamp"],
            )
            delta.grad = None
            
            # 메모리 정리
            del mtcnn_loss, clip_loss, attn_loss, unet_loss, total_loss
            del id_loss_50, id_loss_100, id_loss, lpips_loss
            torch.cuda.empty_cache()
    
    # === 최종 보호 이미지 + 배경 smoothing ===
    bg_smooth_kernel = _make_gaussian_kernel(
        kernel_size=5, sigma=1.0, channels=3, device=device
    )
    delta_blurred = F.conv2d(
        delta.data, bg_smooth_kernel, padding=2, groups=3
    )
    delta.data = delta.data * face_mask + delta_blurred * (1 - face_mask)
    protected = torch.clamp((gt_face * 255) + delta, 0, 255) / 255
    return protected


def _make_gaussian_kernel(kernel_size=5, sigma=1.0, channels=3, device='cuda'):
    """Background smoothing용 Gaussian kernel"""
    coords = torch.arange(kernel_size, dtype=torch.float32, device=device)
    coords -= kernel_size // 2
    g = torch.exp(-coords**2 / (2 * sigma**2))
    g = g / g.sum()
    kernel_2d = g.unsqueeze(0) * g.unsqueeze(1)
    kernel = kernel_2d.unsqueeze(0).unsqueeze(0)
    return kernel.expand(channels, 1, kernel_size, kernel_size)


# ============================================================
# 6. 메인 API (백엔드용)
# ============================================================
def predict_risk(image_input):
    """진짜 위험도 분석 — capstone_pipeline (YOLO + 6DRepNet) 호출"""
    if _capstone_analyze_risk is None:
        return {"success": False, "error": "capstone_pipeline 사용 불가"}
    return _capstone_analyze_risk(image_input)


def protect_image(image_input):
    """
    이미지에 적대적 노이즈를 추가하여 deepfake 보호 처리.
    Args:
        image_input: 파일경로(str) / bytes / numpy / PIL / file-like
    Returns:
        dict {
            "success" (bool),
            "protected_bytes" (bytes or None): PNG 보호 이미지,
            "metrics" (dict): {"px_diff": float},
            "error" (str or None),
        }
    """
    result = {
        "success": False,
        "protected_bytes": None,
        "metrics": None,
        "error": None,
    }
    try:
        pil_img = _to_pil(image_input)
        gt_face = _pil_to_tensor(pil_img, size=PGD_CONFIG["resize_shape"])
        
        with torch.amp.autocast("cuda" if torch.cuda.is_available() else "cpu"):
            protected = _run_pgd(gt_face)
        
        metrics = _compute_metrics(gt_face, protected)
        protected_bytes = _tensor_to_bytes(protected, format="PNG")
        
        result.update({
            "success": True,
            "protected_bytes": protected_bytes,
            "metrics": metrics,
        })
    except Exception as e:
        import traceback
        result["error"] = f"{type(e).__name__}: {str(e)}\n{traceback.format_exc()}"
    
    return result


# ============================================================
# 7. 테스트 (모듈 직접 실행 시)
# ============================================================
if __name__ == "__main__":
    test_path = os.environ.get("TEST_IMAGE", "./data/test/Tom_ori.jpg")
    print(f"[테스트 입력] {test_path}\n")
    
    # 1. 위험도 분석
    print("=== Step 1: 위험도 분석 ===")
    risk = predict_risk(test_path)
    if risk.get('success'):
        print(f"위험도 점수: {risk.get('score')}/100 (level: {risk.get('level')})")
        print(f"세부: yaw={risk.get('yaw'):.2f}, pitch={risk.get('pitch'):.2f}, face_ratio={risk.get('face_ratio'):.4f}")
    else:
        print(f"위험도 분석 실패: {risk.get('error')}")
    
    # 2. 보호 처리
    print("\n=== Step 2: 보호 처리 ===")
    result = protect_image(test_path)
    if result["success"]:
        out_path = "./pipeline_test_output.png"
        with open(out_path, "wb") as f:
            f.write(result["protected_bytes"])
        print(f"[OK] saved to {out_path}")
        print(f"[Metrics] {result['metrics']}")
        print(f"[Size] {len(result['protected_bytes']) / 1024:.1f} KB")
    else:
        print(f"[ERROR]\n{result['error']}")