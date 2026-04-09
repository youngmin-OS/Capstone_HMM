package com.deepfake.controller;

import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.net.MalformedURLException;

@RestController
@RequestMapping("/view")
public class ImageViewController {

    @GetMapping("/{filename}")
    public ResponseEntity<Resource> viewImage(@PathVariable String filename) throws MalformedURLException {

        String path = System.getProperty("user.dir") + "/uploads/" + filename;

        Resource resource = new UrlResource("file:" + path);

        return ResponseEntity.ok()
                .contentType(MediaType.IMAGE_JPEG) // ⭐ 이미지 타입
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "inline; filename=\"" + filename + "\"") // ⭐ 핵심
                .body(resource);
    }
}