import SwiftUI

struct LoginView: View {
    @Binding var showLogin: Bool
    @Binding var showSignup: Bool
    @Binding var isLoggedIn: Bool
    
    @State private var email = ""
    @State private var password = ""
    
    @State private var message = ""
    @State private var showAlert = false
    
    
    var body: some View {
        ZStack {
            VStack {
                Spacer()
                
                VStack(spacing: 20) {
                    
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("로그인")
                                .font(.title)
                                .bold()
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button {
                                showLogin = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        Text("계정에 로그인하세요")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.subheadline)
                    }
                    .padding()
                    .background(
                        LinearGradient(colors: [Color.blue, Color.purple],
                                       startPoint: .leading,
                                       endPoint: .trailing)
                    )
                    
                    VStack(spacing: 15) {
                        CustomTextField(icon: "envelope", placeholder: "이메일", text: $email)
                        CustomSecureField(icon: "lock", placeholder: "비밀번호", text: $password)
                    }
                    .padding(.horizontal, 20)
                    
                    Button {
                        login()
                    } label: {
                        Text("로그인")
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
                    
                    HStack {
                        Text("계정이 없으신가요?")
                            .foregroundColor(.gray)
                        
                        Button("회원가입") {
                            showLogin = false
                            showSignup = true
                        }
                        .foregroundColor(.blue)
                    }
                    .font(.footnote)
                    
                    Spacer()
                }
                .frame(height: 450)
                .background(Color.white)
                .cornerRadius(25)
                .alert(isPresented: $showAlert) {
                    Alert(title: Text(message))
                }
            }
        }
    }
    
    func login() {
        guard let url = URL(string: "http://172.16.8.189:8080/api/users/login") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let body: [String: String] = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let httpResponse = response as? HTTPURLResponse else { return }
            
            DispatchQueue.main.async {
                if httpResponse.statusCode == 200 {
                    if let data = data, let token = String(data: data, encoding: .utf8) {
                        UserDefaults.standard.set(token, forKey: "jwt_token")
                    }
                    isLoggedIn = true
                    showLogin = false
                } else {
                    message = "로그인 실패 😢"
                    showAlert = true
                }
            }
        }.resume()
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(
            showLogin: .constant(true),
            showSignup: .constant(false),
            isLoggedIn: .constant(false)
        )
    }
}
