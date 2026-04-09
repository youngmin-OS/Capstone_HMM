package com.deepfake.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "users") // ⭐ 핵심: user → users 변경
@Getter
@NoArgsConstructor
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String email;
    private String password;
    private String name;

    // 생성자 (필요하면 사용)
    public User(String email, String password, String name) {
        this.email = email;
        this.password = password;
        this.name = name;
    }
}