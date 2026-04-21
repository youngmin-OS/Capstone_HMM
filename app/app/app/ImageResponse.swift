struct ImageResponse: Codable {
    let imageId: Int
    let originalUrl: String
    let processedUrl: String
    let riskScore: Double
}
