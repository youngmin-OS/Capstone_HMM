package com.deepfake.service;

import com.deepfake.domain.Image;
import com.deepfake.dto.ImageUploadResponse;
import com.deepfake.repository.ImageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;

@Service
@RequiredArgsConstructor
public class ImageService {

    private final ImageRepository imageRepository;

    public ImageUploadResponse uploadImage(MultipartFile file) {

        try {
            String fileName = saveFile(file);

            Image image = new Image(file.getOriginalFilename(), fileName, null);
            imageRepository.save(image);

            String resultUrl = "http://localhost:8080/uploads/" + fileName;

            return new ImageUploadResponse(image.getId(), resultUrl);

        } catch (IOException e) {
            throw new RuntimeException("파일 저장 실패");
        }
    }

    private String saveFile(MultipartFile file) throws IOException {

        String uploadDir = System.getProperty("user.dir") + "/uploads/";

        File dir = new File(uploadDir);
        if (!dir.exists()) dir.mkdirs();

        String originalFileName = file.getOriginalFilename();

        // ⭐ 확장자 분리
        String name = originalFileName;
        String extension = "";

        int dotIndex = originalFileName.lastIndexOf(".");
        if (dotIndex != -1) {
            name = originalFileName.substring(0, dotIndex);
            extension = originalFileName.substring(dotIndex); // .jpg 포함
        }

        String fileName = name + extension;
        File saveFile = new File(uploadDir + fileName);

        int count = 1;

        // ⭐ 중복 처리 (확장자 유지)
        while (saveFile.exists()) {
            fileName = name + "(" + count + ")" + extension;
            saveFile = new File(uploadDir + fileName);
            count++;
        }

        file.transferTo(saveFile);

        return fileName;
    }
}