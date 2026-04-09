package com.deepfake.controller;

import com.deepfake.dto.ImageResponse;
import com.deepfake.dto.ImageUploadResponse;
import com.deepfake.service.ImageService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/images")
@RequiredArgsConstructor
public class ImageController {

    private final ImageService imageService;

    // ⭐ userId 포함
    @PostMapping("/upload")
    public ImageUploadResponse upload(
            @RequestParam("file") MultipartFile file,
            @RequestParam("userId") Long userId
    ) {
        return imageService.uploadImage(file, userId);
    }

    // ⭐ 내 이미지 조회
    @GetMapping("/my")
    public List<ImageResponse> getMyImages(
            @RequestParam("userId") Long userId
    ) {
        return imageService.getMyImages(userId);
    }
}