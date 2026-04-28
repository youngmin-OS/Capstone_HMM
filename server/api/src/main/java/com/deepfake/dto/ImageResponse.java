package com.deepfake.dto;

public class ImageResponse {
    private Long id;
    private String fileName;
    private String url;

    public ImageResponse(Long id, String fileName, String url) {
        this.id = id;
        this.fileName = fileName;
        this.url = url;
    }

    public Long getId() { return id; }
    public String getFileName() { return fileName; }
    public String getUrl() { return url; }
}