import UIKit

struct ImageResponse: Codable {
    let imageId: Int
    let resultUrl: String
}

struct AnalyzeResponse: Codable {
    let faceCount: Int
    let faces: [FaceDetail]
    let risk: RiskInfo

    struct FaceDetail: Codable {
        let faceRatio: Double
        let headPose: HeadPose
    }
    struct HeadPose: Codable {
        let yaw: Double
        let pitch: Double
    }
    struct RiskInfo: Codable {
        let score: Double
        let level: String
    }
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

func analyzeImage(image: UIImage, completion: @escaping (AnalyzeResponse?) -> Void) {
    guard let url = URL(string: "https://80152zxv42wpx1-8080.proxy.runpod.net/api/images/analyze") else { return }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    if let token = UserDefaults.standard.string(forKey: "jwt_token") {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
    data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
    request.httpBody = data

    URLSession.shared.dataTask(with: request) { data, response, error in
        // 1. 네트워크 에러 확인
        if let error = error {
            print("❌ 네트워크 오류: \(error.localizedDescription)")
            DispatchQueue.main.async { completion(nil) }
            return
        }

        // 2. HTTP 상태코드 확인
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 응답 코드: \(httpResponse.statusCode)")
        }

        // 3. 응답 데이터 raw 출력
        if let data = data {
            print("📦 응답 데이터: \(String(data: data, encoding: .utf8) ?? "파싱 불가")")
        } else {
            print("❌ data가 nil")
            DispatchQueue.main.async { completion(nil) }
            return
        }

        // 4. 디코딩 에러 상세 출력
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let decoded = try decoder.decode(AnalyzeResponse.self, from: data!)
            DispatchQueue.main.async { completion(decoded) }
        } catch {
            print("❌ 디코딩 실패: \(error)")
            DispatchQueue.main.async { completion(nil) }
        }
    }.resume()
}

func uploadImage(image: UIImage, completion: @escaping (ImageResponse?) -> Void) {
    guard let url = URL(string: "https://80152zxv42wpx1-8080.proxy.runpod.net/api/images/upload") else { return }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"

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
                with: "https://80152zxv42wpx1-8080.proxy.runpod.net"
            )
            DispatchQueue.main.async { completion(ImageResponse(imageId: decoded.imageId, resultUrl: fixedUrl)) }
        } else {
            DispatchQueue.main.async { completion(nil) }
        }
    }.resume()
}
