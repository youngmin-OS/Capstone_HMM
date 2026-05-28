import SwiftUI

struct ResultLoadingView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    @State private var analyzeResult: AnalyzeResponse?
    @State private var filterResult: ImageResponse?
    @State private var phase: Phase = .analyzing
    @State private var isError = false

    enum Phase {
        case analyzing      // 위험도 분석 중
        case showRisk       // 위험도 결과 표시
        case filtering      // 필터 적용 중
        case showResult     // 필터 결과 표시
    }

    var body: some View {
        Group {
            switch phase {
            case .analyzing:
                loadingView(message: "위험도 분석 중...")

            case .showRisk:
                if let analyze = analyzeResult {
                    RiskResultView(
                        image: image,
                        analyzeResult: analyze,
                        onApplyFilter: { applyFilter() },
                        onDismiss: { dismiss() }
                    )
                }

            case .filtering:
                loadingView(message: "필터 적용 중...")

            case .showResult:
                if let result = filterResult {
                    ResultView(image: image, result: result, onDismiss: { dismiss() })
                        .navigationBarHidden(true)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { analyze() }
    }

    @ViewBuilder
    func loadingView(message: String) -> some View {
        VStack(spacing: 20) {
            if isError {
                Text("분석 실패 😢").foregroundColor(.red)
                Button("다시 시도") { analyze() }
            } else {
                Text(message).font(.title2)
                ProgressView()
            }
        }
    }

    func analyze() {
        isError = false
        phase = .analyzing
        analyzeImage(image: image) { result in
            if let result = result {
                analyzeResult = result
                phase = .showRisk
            } else {
                isError = true
            }
        }
    }

    func applyFilter() {
        phase = .filtering
        uploadImage(image: image) { uploadResult in
            guard let uploadResult = uploadResult else {
                isError = true
                phase = .showRisk
                return
            }
            
            protectImage(imageId: uploadResult.imageId) { result in
                if let result = result {
                    filterResult = result
                    phase = .showResult
                } else {
                    isError = true
                    phase = .showRisk
                }
            }
        }
    }
    
}
