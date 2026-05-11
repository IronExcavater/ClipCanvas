import Foundation

struct OpenAIService {
    static func chat(
        userPrompt: String,
        context: String,
        history: [(role: String, content: String)],
        apiKey: String
    ) async throws -> String {
        // Force-unwrap is safe here — the URL literal is a compile-time constant.
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemContent = context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "You are a helpful assistant integrated into ClipCanvas, a clipboard manager app. Be concise."
            : """
              You are a helpful assistant integrated into ClipCanvas, a clipboard manager app.
              The user has selected the following content from their canvas:

              \(context)

              Answer the user's question based on this content. Be concise and helpful.
              """

        // Build the messages array that OpenAI's chat completions API expects.
        // The system message sets the model's persona; history provides conversation context.
        var messages: [[String: String]] = [["role": "system", "content": systemContent]]
        for msg in history {
            messages.append(["role": msg.role, "content": msg.content])
        }
        messages.append(["role": "user", "content": userPrompt])

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "max_tokens": 1000
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // URLSession.shared.data(for:) is the async/await version of the older URLSession
        // completion handler API — it suspends the current task without blocking a thread.
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        guard http.statusCode == 200 else {
            if let err = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw OpenAIError.apiError(err.error.message)
            }
            throw OpenAIError.httpError(http.statusCode)
        }

        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = result.choices.first?.message.content else {
            throw OpenAIError.noContent
        }
        return content
    }
}

// LocalizedError gives these cases a human-readable description that SwiftUI can display directly.
enum OpenAIError: LocalizedError {
    case invalidResponse, noContent
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:    return "Invalid response from OpenAI."
        case .noContent:          return "OpenAI returned no content."
        case .httpError(let c):   return "HTTP error \(c) from OpenAI."
        case .apiError(let msg):  return msg
        }
    }
}

// Codable structs that mirror the JSON shape of OpenAI's chat completions response.
private struct OpenAIResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let message: Message
        struct Message: Decodable { let content: String }
    }
}

private struct OpenAIErrorResponse: Decodable {
    let error: Detail
    struct Detail: Decodable { let message: String }
}
