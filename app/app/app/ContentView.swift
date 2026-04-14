    import SwiftUI

    struct MainView: View {
        @State private var showSignup = false
        @State private var showLogin = false
        
        var body: some View {
            ZStack {
                
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
                    
                    Button(action: {
                                        print("사진 선택")
                                    }) {
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
                    LoginView(showLogin: $showLogin, showSignup: $showSignup)
                        .transition(.move(edge: .bottom))
                }
                    
                if showSignup {
                    SignupView(showSignup: $showSignup, showLogin: $showLogin)
                        .transition(.move(edge: .bottom))
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
