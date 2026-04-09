package com.deepfake.repository;

import com.deepfake.domain.Image;
import com.deepfake.domain.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ImageRepository extends JpaRepository<Image, Long> {

    List<Image> findByUser(User user); // ⭐ 핵심
}