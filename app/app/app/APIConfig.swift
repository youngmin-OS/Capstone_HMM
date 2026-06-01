import Foundation

enum APIConfig {
    static let baseURL = "http://localhost:8080"

    static func url(_ path: String) -> URL? {
        URL(string: baseURL + path)
    }
}
