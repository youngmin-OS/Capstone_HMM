package com.deepfake.dto;

public class ImageUploadResponse {
    private Long imageId;
    private String resultUrl;

    public ImageUploadResponse(Long imageId, String resultUrl) {
        this.imageId = imageId;
        this.resultUrl = resultUrl;
    }

    public Long getImageId() { return imageId; }
    public String getResultUrl() { return resultUrl; }
}