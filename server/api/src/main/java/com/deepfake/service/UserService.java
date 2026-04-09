package com.deepfake.service;

import com.deepfake.domain.User;
import com.deepfake.dto.LoginRequest;
import com.deepfake.dto.UserSignupRequest;
import com.deepfake.jwt.JwtUtil;
import com.deepfake.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final JwtUtil jwtUtil;

    public User signup(UserSignupRequest request) {

        userRepository.findByEmail(request.getEmail())
                .ifPresent(u -> {
                    throw new RuntimeException("이미 존재하는 이메일");
                });

        User user = new User(
                request.getEmail(),
                request.getPassword(),
                request.getName()
        );

        return userRepository.save(user);
    }

    // ⭐ 핵심: String 반환 (토큰)
    public String login(LoginRequest request) {

        User user = userRepository.findByEmail(request.getEmail())
                .filter(u -> u.getPassword().equals(request.getPassword()))
                .orElseThrow(() -> new RuntimeException("로그인 실패"));

        return jwtUtil.createToken(user.getId());
    }
}