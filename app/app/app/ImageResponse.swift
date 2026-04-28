import UIKit

struct ImageResponse: Codable {
    let imageId: Int
    let resultUrl: String
}

func resizeImage(image: UIImage, maxWidth: CGFloat) -> UIImage {
    let ratio = maxWidth / image.size.width
    if ratio >= 1 { return image }
    let newSize = CGSize(width: maxWidth, height: image.size.height * ratio)
    UIGraphicsBeginImageContext(newSize)
    image.draw(in: CGRect(origin: .zero, size: newSize))
    let resized = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    return resized
}

func uploadImage(image: UIImage, completion: @escaping (ImageResponse?) -> Void) {
    guard let url = URL(string: "http://172.16.8.189:8080/api/images/upload") else { return }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    // 토큰 있을 때만 헤더 추가, 없으면 비로그인으로 요청
    if let token = UserDefaults.standard.string(forKey: "jwt_token") {
        print("🔑 토큰 있음: \(token)")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    } else {
        print("👤 비로그인 상태로 요청")
    }

    let boundary = UUID().uuidString
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var data = Data()

    let resized = resizeImage(image: image, maxWidth: 1024)
    guard let imageData = resized.jpegData(compressionQuality: 0.5) else { return }

    data.append("--\(boundary)\r\n".data(using: .utf8)!)
    data.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
    data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
    data.append(imageData)
    data.append("\r\n".data(using: .utf8)!)

    data.append("--\(boundary)\r\n".data(using: .utf8)!)
    data.append("Content-Disposition: form-data; name=\"option\"\r\n\r\n".data(using: .utf8)!)
    data.append("strong\r\n".data(using: .utf8)!)

    data.append("--\(boundary)--\r\n".data(using: .utf8)!)

    request.httpBody = data

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("❌ 네트워크 오류: \(error.localizedDescription)")
            DispatchQueue.main.async { completion(nil) }
            return
        }

        if let httpResponse = response as? HTTPURLResponse {
            print("📥 응답 코드: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 401 {
                // 토큰 만료 → 삭제
                UserDefaults.standard.removeObject(forKey: "jwt_token")
                DispatchQueue.main.async { completion(nil) }
                return
            }
        }

        guard let data = data else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        print("📦 응답 데이터: \(String(data: data, encoding: .utf8) ?? "파싱 불가")")

        if let decoded = try? JSONDecoder().decode(ImageResponse.self, from: data) {
            let fixedUrl = decoded.resultUrl.replacingOccurrences(
                of: "http://localhost:8080",
                with: "http://172.16.8.189:8080"
            )
            let fixedResult = ImageResponse(imageId: decoded.imageId, resultUrl: fixedUrl)
            DispatchQueue.main.async { completion(fixedResult) }
        } else {
            DispatchQueue.main.async { completion(nil) }
        }
    }.resume()
}
