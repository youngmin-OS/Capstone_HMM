package com.deepfake.controller;

import com.deepfake.dto.ImageUploadResponse;
import com.deepfake.service.ImageService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/images")
@RequiredArgsConstructor
public class ImageController {

    private final ImageService imageService;

    @PostMapping("/upload")
    public ResponseEntity<ImageUploadResponse> uploadImage(
            @RequestParam("file") MultipartFile file) {

        ImageUploadResponse response = imageService.uploadImage(file);
        return ResponseEntity.ok(response);
    }
}