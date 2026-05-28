import SwiftUI

struct RiskResultView: View {
    @State private var showInfo = false
    
    let image: UIImage
    let analyzeResult: AnalyzeResponse
    let onApplyFilter: () -> Void
    let onDismiss: () -> Void

    var scorePercent: Double { Double(analyzeResult.overallRisk) / 100.0 }

    var gaugeColor: Color {
        if scorePercent >= 0.7 { return .red }
        if scorePercent >= 0.4 { return .orange }
        return .green
    }
    
    var infoMessage: String {
        if scorePercent >= 0.7 {
            return "얼굴이 이미지에서 충분한 크기로 촬영되었고 정면을 향하고 있습니다. 이는 얼굴 인식 모델이 특징점을 정밀하게 추출할 수 있는 조건으로, 딥페이크 생성에 직접 활용될 수 있습니다. FaceShield 보호 적용을 권장합니다."
        } else if scorePercent >= 0.4 {
            return "얼굴 크기 또는 각도 중 한 가지 조건이 딥페이크 생성에 불리하게 작용하고 있습니다. 조건이 개선된 다른 사진과 함께 사용될 경우 위험도가 높아질 수 있으므로, 보호 적용을 고려해보세요."
        } else {
            return "얼굴 영역이 이미지에서 차지하는 비율이 낮거나, 얼굴이 측면을 향하고 있습니다. 이 경우 얼굴 인식 모델이 특징점을 충분히 추출하기 어려워, 딥페이크 생성에 필요한 조건을 갖추지 못한 상태입니다."
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // 원본 이미지
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(14)
                    .padding(.horizontal)
                    .padding(.top, 16)

                // 위험도 카드
                VStack(spacing: 14) {
                    HStack {
                            Spacer()
                            Text("딥페이크 위험도")
                                .font(.headline)
                            Spacer()
                            Button {
                                showInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 18))
                            }
                        }

                    // 점수 숫자
                    Text(String(format: "%.0f%%", scorePercent * 100))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(gaugeColor)

                    // 게이지 바
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(height: 14)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(gaugeColor)
                                .frame(width: geo.size.width * scorePercent, height: 14)
                                .animation(.easeOut(duration: 0.6), value: scorePercent)
                        }
                    }
                    .frame(height: 14)

                    // 범례
                    HStack {
                        Text("낮음").font(.caption).foregroundColor(.green)
                        Spacer()
                        Text("중간").font(.caption).foregroundColor(.orange)
                        Spacer()
                        Text("높음").font(.caption).foregroundColor(.red)
                        
                    }
                    .alert("위험도 안내", isPresented: $showInfo) {
                        Button("확인", role: .cancel) {}
                    } message: {
                        Text(infoMessage)
                    }

                    if analyzeResult.overallRisk == 0 {
                        Text("얼굴이 감지되지 않았습니다")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)

                Button(action: onApplyFilter) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("딥페이크 방지 필터 적용")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(colors: [.blue, .purple],
                                       startPoint: .leading,
                                       endPoint: .trailing)
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                Button("취소") { onDismiss() }
                    .foregroundColor(.gray)
                    .font(.subheadline)
                    .padding(.bottom, 20)
            }
        }
    }
}

#Preview {
    RiskResultView(
        image: UIImage(systemName: "person.fill")!,
        analyzeResult: AnalyzeResponse(
            overallRisk: 72,
            riskLabel: "높음",
            lpipsRisk: 0.1,
            clipRisk: 0.4,
            arcRisk: 0.03
        ),
        onApplyFilter: {},
        onDismiss: {}
    )
}
