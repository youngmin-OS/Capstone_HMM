package com.deepfake.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Getter
@NoArgsConstructor
public class Image {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String fileName;   // 원본 이름
    private String filePath;   // 저장된 이름

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    public Image(String fileName, String filePath, User user) {
        this.fileName = fileName;
        this.filePath = filePath;
        this.user = user;
    }
}