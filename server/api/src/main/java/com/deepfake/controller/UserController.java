package com.deepfake.controller;

import com.deepfake.dto.LoginRequest;
import com.deepfake.dto.UserSignupRequest;
import com.deepfake.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @PostMapping("/signup")
    public Object signup(@RequestBody UserSignupRequest request) {
        return userService.signup(request);
    }

    // ⭐ 여기 중요 (String 반환)
    @PostMapping("/login")
    public String login(@RequestBody LoginRequest request) {
        return userService.login(request);
    }
}