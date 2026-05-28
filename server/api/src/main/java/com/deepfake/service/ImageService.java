package com.deepfake.service;

import com.deepfake.domain.Image;
import com.deepfake.domain.User;
import com.deepfake.dto.AnalyzeResult;
import com.deepfake.dto.ImageResponse;
import com.deepfake.dto.ImageUploadResponse;
import com.deepfake.entity.ImageStatus;
import com.deepfake.external.FaceShieldClient;
import com.deepfake.repository.ImageRepository;
import com.deepfake.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class ImageService {

    private final ImageRepository imageRepository;
    private final UserRepository userRepository;
    private final FaceShieldClient faceShieldClient;
    private final String appBaseUrl;

    @Autowired
    public ImageService(
            ImageRepository imageRepository,
            UserRepository userRepository,
            FaceShieldClient faceShieldClient,
            @Value("${app.base-url}") String appBaseUrl
    ) {
        this.imageRepository = imageRepository;
        this.userRepository = userRepository;
        this.faceShieldClient = faceShieldClient;
        this.appBaseUrl = trimTrailingSlash(appBaseUrl);
    }

    public ImageUploadResponse uploadImage(
            MultipartFile file,
            Long userId
    ) {

        try {

            User user = null;

            if (userId != null) {
                user = userRepository.findById(userId)
                        .orElseThrow(() ->
                                new RuntimeException("유저 없음"));
            }

            byte[] fileBytes = file.getBytes();
            String originalName = file.getOriginalFilename();

            if (originalName == null || originalName.isBlank()) {
                throw new RuntimeException("파일 이름 없음");
            }

            String savedName = saveFile(fileBytes, originalName);

            Image image = new Image(
                    originalName,
                    savedName,
                    user
            );

            image.setStatus(ImageStatus.PENDING);
            imageRepository.save(image);

            analyzeAsync(image.getId(), fileBytes, originalName);

            return new ImageUploadResponse(
                    image.getId(),
                    buildViewUrl(savedName),
                    null
            );

        } catch (IOException e) {
            throw new RuntimeException("파일 저장 실패");
        }
    }

    @Async
    public void analyzeAsync(
            Long imageId,
            byte[] fileBytes,
            String originalName
    ) {

        Image image = imageRepository.findById(imageId)
                .orElseThrow(() ->
                        new RuntimeException("이미지 없음"));

        try {

            image.setStatus(ImageStatus.ANALYZING);
            imageRepository.save(image);

            AnalyzeResult result =
                    faceShieldClient.analyze(fileBytes, originalName);

            double score = result.getOverallRisk() / 100.0;
            image.setRiskScore(score);
            image.setRiskDescription(getRiskDescription(score));

            image.setStatus(ImageStatus.COMPLETED);
            imageRepository.save(image);

        } catch (Exception e) {

            image.setStatus(ImageStatus.FAILED);
            image.setErrorMessage(e.getMessage());
            imageRepository.save(image);

            e.printStackTrace();
        }
    }

    private String getRiskDescription(double score) {
        if (score < 0.4) {
            return "얼굴 영역이 이미지에서 차지하는 비율이 낮거나, 얼굴이 측면을 향하고 있습니다. " +
                    "이 경우 얼굴 인식 모델이 특징점을 충분히 추출하기 어려워, " +
                    "딥페이크 생성에 필요한 조건을 갖추지 못한 상태입니다.";
        } else if (score < 0.7) {
            return "얼굴 크기 또는 정면 각도 중 한 가지 조건이 완전히 충족되지 않은 상태입니다. " +
                    "조건이 개선된 다른 사진과 함께 사용될 경우 위험도가 높아질 수 있으므로, " +
                    "보호 적용을 고려해 보세요.";
        } else {
            return "얼굴이 이미지에서 충분한 크기로 촬영되었고 정면을 향하고 있습니다. " +
                    "이는 얼굴 인식 모델이 특징점을 정밀하게 추출할 수 있는 조건으로, " +
                    "딥페이크 생성에 직접 활용될 수 있습니다. FaceShield 보호 적용을 권장합니다.";
        }
    }

    public List<ImageResponse> getMyImages(Long userId) {

        if (userId == null) {
            throw new RuntimeException("로그인이 필요합니다.");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() ->
                        new RuntimeException("유저 없음"));

        return imageRepository.findByUser(user)
                .stream()
                .map(img -> new ImageResponse(
                        img.getId(),
                        img.getFileName(),
                        buildViewUrl(img.getFilePath()),
                        img.getStatus().name(),
                        img.getRiskScore(),
                        img.getRiskDescription(),
                        buildNullableViewUrl(img.getResultPath()),
                        img.getErrorMessage()
                ))
                .collect(Collectors.toList());
    }

    public ImageResponse protectImage(Long imageId) {

        Image image = imageRepository.findById(imageId)
                .orElseThrow(() -> new RuntimeException("이미지 없음"));

        try {
            String uploadDir = System.getProperty("user.dir") + "/uploads/";
            byte[] fileBytes = Files.readAllBytes(
                    new File(uploadDir + image.getFilePath()).toPath()
            );

            byte[] protectedBytes = faceShieldClient.protect(fileBytes, image.getFileName());

            String savedName = saveFile(protectedBytes, "protected_" + image.getFileName());
            image.setResultPath(savedName);
            image.setStatus(ImageStatus.COMPLETED);
            imageRepository.save(image);

            return new ImageResponse(
                    image.getId(),
                    image.getFileName(),
                    buildViewUrl(image.getFilePath()),
                    image.getStatus().name(),
                    image.getRiskScore(),
                    image.getRiskDescription(),
                    buildViewUrl(savedName),
                    null
            );

        } catch (Exception e) {
            image.setStatus(ImageStatus.FAILED);
            image.setErrorMessage(e.getMessage());
            imageRepository.save(image);
            throw new RuntimeException("보호 처리 실패: " + e.getMessage());
        }
    }

    public ImageResponse getImageResult(Long imageId) {

        Image img = imageRepository.findById(imageId)
                .orElseThrow(() ->
                        new RuntimeException("이미지 없음"));

        return new ImageResponse(
                img.getId(),
                img.getFileName(),
                buildViewUrl(img.getFilePath()),
                img.getStatus().name(),
                img.getRiskScore(),
                img.getRiskDescription(),
                buildNullableViewUrl(img.getResultPath()),
                img.getErrorMessage()
        );
    }

    private String saveFile(byte[] fileBytes, String originalName)
            throws IOException {

        String uploadDir =
                System.getProperty("user.dir") + "/uploads/";

        File dir = new File(uploadDir);
        if (!dir.exists()) {
            dir.mkdirs();
        }

        String safeOriginalName = toSafeFileName(originalName);
        int dotIndex = safeOriginalName.lastIndexOf(".");
        String extension = (dotIndex >= 0)
                ? safeOriginalName.substring(dotIndex)
                : "";

        String savedName = UUID.randomUUID() + extension;
        File saveFile = new File(uploadDir + savedName);

        Files.write(saveFile.toPath(), fileBytes);

        System.out.println("저장 완료: " + saveFile.getAbsolutePath());
        System.out.println("저장 파일 크기: " + saveFile.length());

        return saveFile.getName();
    }

    private String buildViewUrl(String fileName) {
        return appBaseUrl + "/view/" + fileName;
    }

    private String buildNullableViewUrl(String fileName) {
        return fileName == null || fileName.isBlank() ? null : buildViewUrl(fileName);
    }

    private String trimTrailingSlash(String value) {
        if (value == null || value.isBlank()) {
            return "http://localhost:8080";
        }

        return value.endsWith("/") ? value.substring(0, value.length() - 1) : value;
    }

    private String toSafeFileName(String fileName) {
        if (fileName == null || fileName.isBlank()) {
            return "image.jpg";
        }

        String safeName = fileName.replaceAll("[^A-Za-z0-9._-]", "_");
        if (safeName.isBlank() || safeName.replace("_", "").isBlank()) {
            return "image.jpg";
        }

        return safeName;
    }
}
