package com.deepfake.service;

import com.deepfake.domain.Image;
import com.deepfake.domain.User;
import com.deepfake.dto.ImageResponse;
import com.deepfake.dto.ImageUploadResponse;
import com.deepfake.repository.ImageRepository;
import com.deepfake.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class ImageService {

    private final ImageRepository imageRepository;
    private final UserRepository userRepository;

    @Autowired
    public ImageService(ImageRepository imageRepository, UserRepository userRepository) {
        this.imageRepository = imageRepository;
        this.userRepository = userRepository;
    }

    public ImageUploadResponse uploadImage(MultipartFile file, Long userId) {

        try {
            User user = null;
            if (userId != null) {
                user = userRepository.findById(userId)
                        .orElseThrow(() -> new RuntimeException("유저 없음"));
            }

            String fileName = saveFile(file);

            Image image = new Image(
                    file.getOriginalFilename(),
                    fileName,
                    user
            );

            imageRepository.save(image);

            String url = "http://localhost:8080/uploads/" + fileName;

            return new ImageUploadResponse(image.getId(), url);

        } catch (IOException e) {
            throw new RuntimeException("파일 저장 실패");
        }
    }

    public List<ImageResponse> getMyImages(Long userId) {

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("유저 없음"));

        return imageRepository.findByUser(user)
                .stream()
                .map(img -> new ImageResponse(
                        img.getId(),
                        img.getFileName(),
                        "http://localhost:8080/uploads/" + img.getFilePath()
                ))
                .collect(Collectors.toList());
    }

    private String saveFile(MultipartFile file) throws IOException {

        String uploadDir = System.getProperty("user.dir") + "/uploads/";
        File dir = new File(uploadDir);
        if (!dir.exists()) dir.mkdirs();

        String originalFileName = file.getOriginalFilename();
        File saveFile = new File(uploadDir + originalFileName);

        int count = 1;

        while (saveFile.exists()) {
            int dot = originalFileName.lastIndexOf(".");
            String name = originalFileName.substring(0, dot);
            String ext = originalFileName.substring(dot);

            String newName = name + "(" + count + ")" + ext;
            saveFile = new File(uploadDir + newName);
            count++;
        }

        file.transferTo(saveFile);

        return saveFile.getName();
    }
}