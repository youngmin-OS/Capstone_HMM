package com.deepfake.service;

import com.deepfake.domain.User;
import com.deepfake.dto.LoginRequest;
import com.deepfake.dto.UserSignupRequest;
import com.deepfake.jwt.JwtUtil;
import com.deepfake.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final JwtUtil jwtUtil;

    @Autowired
    public UserService(UserRepository userRepository, JwtUtil jwtUtil) {
        this.userRepository = userRepository;
        this.jwtUtil = jwtUtil;
    }

    public void signup(UserSignupRequest request) {
        if (userRepository.findByEmail(request.getEmail()).isPresent()) {
            throw new RuntimeException("이미 존재하는 이메일");
        }

        User user = new User(
                request.getEmail(),
                request.getPassword(),
                request.getName()
        );

        userRepository.save(user);
    }

    public String login(LoginRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new RuntimeException("유저 없음"));

        if (!user.getPassword().equals(request.getPassword())) {
            throw new RuntimeException("비밀번호 불일치");
        }

        return jwtUtil.createToken(user.getId());
    }
}