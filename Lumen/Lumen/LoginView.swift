import SwiftUI
import AuthenticationServices

struct LoginView: View {
    var onLogin: (String?, String?) -> Void

    struct FeatureItem: Identifiable {
        let id = UUID()
        let title: String
        let imageName: String
    }

    let features: [FeatureItem] = [
        FeatureItem(title: "Record lectures in high quality", imageName: "mic.fill"),
        FeatureItem(title: "Convert recordings to bullet-point notes", imageName: "list.bullet.clipboard.fill"),
        FeatureItem(title: "Sync notes across all your devices", imageName: "icloud.fill"),
        FeatureItem(title: "Visualize your study insights", imageName: "chart.pie.fill")
    ]
    
    @State private var showGreeting = false
    @State private var showWelcomeMessage = false
    @State private var showFeatures = false
    @State private var showTestimonial = false
    @State private var showSignInButton = false
    @State private var selectedFeatureIndex = 0

    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    @Environment(\.colorScheme) var colorScheme

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good Morning"
        } else if hour < 18 {
            return "Good Afternoon"
        } else {
            return "Good Evening"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(greeting)
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundColor(Color.primary)
                    .opacity(showGreeting ? 1 : 0)
                    .offset(y: showGreeting ? 0 : 20)
                Text("Welcome to Lumen")
                    .font(.system(size: 22, weight: .medium, design: .default))
                    .foregroundColor(Color.secondary)
                    .opacity(showWelcomeMessage ? 1 : 0)
                    .offset(y: showWelcomeMessage ? 0 : 20)
            }
            .padding(.top, 50)
            .padding(.bottom, 30)
            
            TabView(selection: $selectedFeatureIndex) {
                ForEach(features.indices, id: \.self) { index in
                    VStack(spacing: 15) {
                        Image(systemName: features[index].imageName)
                            .font(.system(size: 50))
                            .foregroundColor(Color.accentColor)
                        Text(features[index].title)
                            .font(.system(size: 18, weight: .regular, design: .default))
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color.primary)
                            .padding(.horizontal, 30)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(showFeatures && selectedFeatureIndex == index ? 1 : 0.8)
                    .scaleEffect(showFeatures && selectedFeatureIndex == index ? 1 : 0.95)
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .frame(height: 200)
            .opacity(showFeatures ? 1 : 0)
            .onReceive(timer) { _ in
                withAnimation(.easeInOut(duration: 0.8)) {
                    selectedFeatureIndex = (selectedFeatureIndex + 1) % features.count
                }
            }
            .padding(.bottom, 30)

            VStack(spacing: 10) {
                HStack {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.callout)
                    }
                }
                Text("\"Lumen has revolutionized my study habits. The AI-powered notes are a game changer!\"")
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(Color.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Text("- A Happy Student")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundColor(Color.primary)
            }
            .padding(.vertical, 20)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(15)
            .padding(.horizontal, 20)
            .opacity(showTestimonial ? 1 : 0)
            .offset(y: showTestimonial ? 0 : 20)
            
            Spacer()
            
            SignInWithAppleButton(
                .signUp,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                            let userIdentifier = appleIDCredential.user
                            let fullName = appleIDCredential.fullName
                            let email = appleIDCredential.email
                            
                            let firstName = fullName?.givenName
                            let lastName = fullName?.familyName
                            var nameParts: [String] = []
                            if let first = firstName { nameParts.append(first) }
                            if let last = lastName { nameParts.append(last) }
                            let formattedName = nameParts.joined(separator: " ")

                            print("User ID: \(userIdentifier)")
                            print("User Name: \(formattedName)")
                            print("User Email: \(email ?? "Not provided")")
                            
                            onLogin(formattedName.isEmpty ? nil : formattedName, email)
                        }
                    case .failure(let error):
                        print("Apple Sign In Error: \(error.localizedDescription)")
                    }
                }
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(width: 280, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.bottom, 50)
            .opacity(showSignInButton ? 1 : 0)
            .offset(y: showSignInButton ? 0 : 20)
        }
        .padding(.horizontal)
        .background(Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all))
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                showGreeting = true
            }
            withAnimation(.easeOut(duration: 0.7).delay(0.2)) {
                showWelcomeMessage = true
            }
            withAnimation(.easeOut(duration: 0.7).delay(0.4)) {
                showFeatures = true
            }
            withAnimation(.easeOut(duration: 0.7).delay(0.6)) {
                showTestimonial = true
            }
            withAnimation(.easeOut(duration: 0.7).delay(0.8)) {
                showSignInButton = true
            }
        }
    }
}
