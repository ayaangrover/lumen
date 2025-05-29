import Foundation

let groqAPIKey = "API_KEY"

struct GroqResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
    let usage: UsageData?

    struct UsageData: Codable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?
        let completionTime: Double?
        let promptTime: Double?
    }
}


class GroqService {
    private let apiURL = URL(string: "https://api.groq.com/openai/v1/chat/completions")!

    enum GroqError: Error {
        case invalidURL
        case requestFailed(Error)
        case invalidResponse
        case apiError(String)
        case decodingError(Error)
    }

    private func makeRequest(prompt: String, systemContent: String, maxTokens: Int = 150) async throws -> String {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(groqAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let combinedContent = "\(systemContent)\n\n\(prompt)"

        let requestBody: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [
                ["role": "user", "content": combinedContent]
            ],
            "max_tokens": maxTokens,
            "temperature": 0.7
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown API error"
            print("Groq API Error (Status \(httpResponse.statusCode)): \(errorBody)")
            throw GroqError.apiError("Request failed with status \(httpResponse.statusCode): \(errorBody)")
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(GroqResponse.self, from: data)
            if let content = decodedResponse.choices.first?.message.content {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                throw GroqError.invalidResponse
            }
        } catch {
            print("Groq Decoding Error: \(error)")
            throw GroqError.decodingError(error)
        }
    }

    func generateTitle(for text: String) async throws -> String {
        let systemContent = "You are an expert at creating concise, informative titles for notes based on their content. Generate a short title (max 5 words) for the following text. Do not add any prefix like 'Title:' or quotes."
        let title = try await makeRequest(prompt: text, systemContent: systemContent, maxTokens: 20)
        return title.replacingOccurrences(of: "\"", with: "")
    }

    func generateSummary(for text: String) async throws -> String {
        let systemContent = "You are an expert at summarizing text. Provide a concise summary of the following content. Do not include phrases like 'Here is your summary:' or 'In summary,'. Just provide the summary directly. Do not use bullet points."
        var summary = try await makeRequest(prompt: text, systemContent: systemContent, maxTokens: 200)
        
        let prefixesToRemove = ["Here's a summary:", "Here is a summary:", "Summary:"]
        for prefix in prefixesToRemove {
            if summary.lowercased().hasPrefix(prefix.lowercased()) {
                summary = String(summary.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return summary
    }

    func generateChatResponse(prompt: String, notesContext: String, chatHistory: [ChatMessageModel]) async throws -> String {
        var messages: [[String: String]] = []

        let systemInstruction = "CONTEXT FROM USER'S NOTES (Use this to inform your responses):\n\(notesContext)\n\nIMPORTANT: Keep your responses concise and to the point."
        messages.append(["role": "system", "content": systemInstruction])

        for messageEntry in chatHistory {
            messages.append(["role": messageEntry.role.rawValue, "content": messageEntry.content])
        }
        return try await makeChatRequest(prompt: prompt, history: messages)
    }

    private func makeChatRequest(prompt: String, history: [[String: String]], maxTokens: Int = 500) async throws -> String {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(groqAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var messages = history
        messages.append(["role": "user", "content": prompt])

        let requestBody: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": 0.7
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown API error"
            print("Groq Chat API Error (Status \(httpResponse.statusCode)): \(errorBody)")
            throw GroqError.apiError("Request failed with status \(httpResponse.statusCode): \(errorBody)")
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(GroqResponse.self, from: data)
            if let content = decodedResponse.choices.first?.message.content {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                throw GroqError.invalidResponse
            }
        } catch {
            print("Groq Chat Decoding Error: \(error)")
            throw GroqError.decodingError(error)
        }
    }

    func testGenericAPIConnection() async {
        print("Attempting to connect to a generic test API...")
        guard let testURL = URL(string: "https://jsonplaceholder.typicode.com/todos/1") else {
            print("Test API: Invalid URL")
            return
        }
        
        var request = URLRequest(url: testURL)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("Test API Response Status: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Test API Response Data: \(responseString.prefix(200))...")
                }
                if (200...299).contains(httpResponse.statusCode) {
                    print("Test API: Successfully connected and received data.")
                } else {
                    print("Test API: Failed with status code \(httpResponse.statusCode).")
                }
            } else {
                print("Test API: Did not receive a valid HTTP response.")
            }
        } catch {
            print("Test API: Request failed with error: \(error.localizedDescription)")
        }
    }
}
