package com.deepfake.controller;

import com.deepfake.dto.ImageResponse;
import com.deepfake.dto.ImageUploadResponse;
import com.deepfake.service.ImageService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/images")
@RequiredArgsConstructor
public class ImageController {

    private final ImageService imageService;

    @PostMapping("/upload")
    public ImageUploadResponse upload(
            HttpServletRequest request,
            @RequestParam("file") MultipartFile file
    ) {

        Long userId = (Long) request.getAttribute("userId");

        return imageService.uploadImage(file, userId);
    }

    @GetMapping("/my")
    public List<ImageResponse> getMyImages(
            HttpServletRequest request
    ) {

        Long userId = (Long) request.getAttribute("userId");

        return imageService.getMyImages(userId);
    }
}