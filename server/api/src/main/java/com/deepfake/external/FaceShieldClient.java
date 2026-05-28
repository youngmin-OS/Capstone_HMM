package com.deepfake.external;

import com.deepfake.dto.AnalyzeResult;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;

@Component
public class FaceShieldClient {

    @Value("${ai.server.url}")
    private String aiServerUrl;

    private final RestTemplate restTemplate;

    public FaceShieldClient(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    public AnalyzeResult analyze(byte[] fileBytes, String originalName) {
        ResponseEntity<AnalyzeResult> response = restTemplate.postForEntity(
                aiServerUrl + "/api/analyze",
                buildMultipartRequest(fileBytes, originalName),
                AnalyzeResult.class
        );

        if (response.getBody() == null) {
            throw new RuntimeException("AI 분석 실패");
        }

        return response.getBody();
    }

    public byte[] protect(byte[] fileBytes, String originalName) {
        ResponseEntity<byte[]> response = restTemplate.postForEntity(
                aiServerUrl + "/api/protect",
                buildMultipartRequest(fileBytes, originalName),
                byte[].class
        );

        if (response.getBody() == null) {
            throw new RuntimeException("AI 보호 처리 실패");
        }

        return response.getBody();
    }

    private HttpEntity<MultiValueMap<String, Object>> buildMultipartRequest(byte[] fileBytes, String fileName) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);

        ByteArrayResource fileResource = new ByteArrayResource(fileBytes) {
            @Override
            public String getFilename() {
                return toSafeFileName(fileName);
            }
        };

        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("file", fileResource);

        return new HttpEntity<>(body, headers);
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
