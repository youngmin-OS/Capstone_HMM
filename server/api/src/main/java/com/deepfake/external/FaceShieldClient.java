package com.deepfake.external;

import org.springframework.stereotype.Component;

@Component
public class FaceShieldClient {

    public String processImage(String filePath) {

        // 파일명만 추출
        String fileName = filePath.substring(filePath.lastIndexOf("/") + 1);

        return "http://localhost:8080/uploads/" + fileName;
    }
}