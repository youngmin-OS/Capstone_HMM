package com.deepfake.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public class ImageResponse {

    private Long id;
    private String fileName;
    private String url;
}