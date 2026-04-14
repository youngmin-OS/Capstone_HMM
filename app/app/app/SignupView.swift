import SwiftUI

struct SignupView: View {
    @Binding var showSignup: Bool
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        ZStack {
            
            VStack {
                Spacer()
                
                VStack(spacing: 20) {
                    
                    // 헤더
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("회원가입")
                                .font(.title)
                                .bold()
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        Text("새 계정을 만드세요")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.subheadline)
                    }
                    .padding()
                    .background(
                        LinearGradient(colors: [Color.blue, Color.purple],
                                       startPoint: .leading,
                                       endPoint: .trailing)
                    )
                    
                    // 입력 필드
                    VStack(spacing: 15) {
                        
                        CustomTextField(icon: "person", placeholder: "이름", text: $name)
                        CustomTextField(icon: "envelope", placeholder: "이메일", text: $email)
                        CustomSecureField(icon: "lock", placeholder: "비밀번호", text: $password)
                    }
                    .padding(.horizontal, 20)
                    
                    // 회원가입 버튼
                    Button(action: {
                        signup()
                    }) {
                        Text("회원가입")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [Color.blue, Color.purple],
                                               startPoint: .leading,
                                               endPoint: .trailing)
                            )
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    
                    // 로그인 이동
                    HStack {
                        Text("이미 계정이 있으신가요?")
                            .foregroundColor(.gray)
                        
                        Button("로그인") {
                            // 로그인 화면으로 이동
                        }
                        .foregroundColor(.blue)
                    }
                    .font(.footnote)
                    
                    Spacer()
                }
                .frame(height: 500)
                .background(Color.white)
                .cornerRadius(25)
            }
        }
    }
    
    // 회원가입 API
    func signup() {
        guard let url = URL(string: "http://YOUR_IP:8080/api/users/signup") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let body: [String: String] = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request).resume()
    }
}

struct CustomTextField: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct CustomSecureField: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
            
            SecureField(placeholder, text: $text)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct SignupView_Previews: PreviewProvider {
    static var previews: some View {
        SignupView(showSignup: .constant(true))
    }
}
