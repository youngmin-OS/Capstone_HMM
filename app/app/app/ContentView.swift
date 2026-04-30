import SwiftUI
import PhotosUI

struct MainView: View {
    @State private var showSignup = false
    @State private var showLogin = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var goLoading = false
    @State private var isLoggedIn = false
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ZStack {
                NavigationLink("", isActive: $goLoading) {
                    ResultLoadingView(image: selectedImage ?? UIImage())
                }
                .opacity(0)

                VStack(spacing: 20) {
                    Text("딥페이크 노이즈")
                        .font(.headline)
                        .padding(.top, 30)

                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.purple)

                        Text("이미지 업로드")
                            .font(.title2)
                            .bold()

                        Text("딥페이크 노이즈 효과를 적용할 이미지를 선택하세요")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Text("사진 선택하기")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                            .padding(.horizontal, 40)
                    }

                    VStack(spacing: 15) {
                        FeatureCard(icon: "sparkles", title: "자동 노이즈 적용", description: "업로드하면 즉시 딥페이크 노이즈 효과가 적용됩니다")
                        FeatureCard(icon: "arrow.down.circle", title: "쉬운 저장 및 공유", description: "처리된 이미지를 바로 저장하거나 공유")
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    if isLoggedIn {
                        Button {
                            showHistory = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("이력관리")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [Color.purple, Color.blue],
                                               startPoint: .leading,
                                               endPoint: .trailing)
                            )
                            .cornerRadius(10)
                            .padding(.horizontal, 40)
                        }
                        .padding(.bottom, 20)
                    } else {
                        Button {
                            showLogin = true
                        } label: {
                            Text("로그인 / 회원가입")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(colors: [Color.purple, Color.blue],
                                                   startPoint: .leading,
                                                   endPoint: .trailing)
                                )
                                .cornerRadius(10)
                                .padding(.horizontal, 40)
                        }
                        .padding(.bottom, 20)
                    }
                }
                .blur(radius: (showSignup || showLogin) ? 5 : 0)

                if showSignup || showLogin {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showSignup = false
                            showLogin = false
                        }
                }

                if showLogin {
                    LoginView(showLogin: $showLogin, showSignup: $showSignup, isLoggedIn: $isLoggedIn)
                        .transition(.move(edge: .bottom))
                }

                if showSignup {
                    SignupView(showSignup: $showSignup, showLogin: $showLogin)
                        .transition(.move(edge: .bottom))
                }
            }
            .onAppear {
                if let token = UserDefaults.standard.string(forKey: "jwt_token") {
                    let parts = token.split(separator: ".")
                    if parts.count == 3 {
                        var base64 = String(parts[1])
                        let remainder = base64.count % 4
                        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }
                        
                        if let data = Data(base64Encoded: base64),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let exp = json["exp"] as? TimeInterval,
                           Date().timeIntervalSince1970 < exp {
                            isLoggedIn = true
                        } else {
                            // ✅ 만료된 토큰 확실히 삭제
                            UserDefaults.standard.removeObject(forKey: "jwt_token")
                            UserDefaults.standard.synchronize() // 즉시 반영
                            isLoggedIn = false
                        }
                    } else {
                        // ✅ 잘못된 형식의 토큰도 삭제
                        UserDefaults.standard.removeObject(forKey: "jwt_token")
                        UserDefaults.standard.synchronize()
                        isLoggedIn = false
                    }
                } else {
                    isLoggedIn = false
                }
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            selectedImage = uiImage
                        }
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        await MainActor.run {
                            goLoading = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(isLoggedIn: $isLoggedIn)
                    .environmentObject(HistoryStore.shared)
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}

struct FeatureCard: View {
    var icon: String
    var title: String
    var description: String

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .resizable()
                .frame(width: 25, height: 25)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}
