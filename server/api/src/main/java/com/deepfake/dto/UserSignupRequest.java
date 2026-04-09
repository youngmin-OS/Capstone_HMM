package com.deepfake.dto;

import lombok.Getter;

@Getter
public class UserSignupRequest {

    private String email;
    private String password;
    private String name;
}