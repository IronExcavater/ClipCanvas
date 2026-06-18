import Foundation

nonisolated enum OpenAIConfiguration {
    static let apiKeyUserDefaultsKey = "settings.openAIAPIKey"
    static let modelUserDefaultsKey = "settings.openAIModel"

    static var apiKey: String? {
        if let stored = UserDefaults.standard.string(forKey: apiKeyUserDefaultsKey),
           !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return stored.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let environment = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
           !environment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return environment.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let bundled = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String,
           !bundled.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return bundled.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    static func model(default fallback: String) -> String {
        if let stored = UserDefaults.standard.string(forKey: modelUserDefaultsKey),
           !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return stored.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let environment = ProcessInfo.processInfo.environment["OPENAI_MODEL"],
           !environment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return environment.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return fallback
    }
}

enum OpenAIResponsesClientError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "OpenAI API key is missing."
        case .invalidResponse:
            "OpenAI returned an unreadable response."
        case .requestFailed(let message):
            message
        }
    }
}

struct OpenAIResponsesClient {
    var apiKey: String?
    var session: URLSession = .shared

    init(apiKey: String? = OpenAIConfiguration.apiKey, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func response(model: String, instructions: String, input: String, previousResponseID: String? = nil) async throws -> OpenAIResponseResult {
        guard let apiKey, !apiKey.isEmpty else {
            throw OpenAIResponsesClientError.missingAPIKey
        }
        let requestBody = OpenAIResponsesRequest(
            model: model,
            instructions: instructions,
            input: input,
            previousResponseID: previousResponseID
        )
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OpenAIResponsesClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let error = (try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data).error.message)
            throw OpenAIResponsesClientError.requestFailed(error ?? "OpenAI request failed with HTTP \(http.statusCode).")
        }

        let decoded = try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)
        guard let text = decoded.displayText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIResponsesClientError.invalidResponse
        }
        return OpenAIResponseResult(id: decoded.id, text: text)
    }
}

nonisolated struct OpenAIResponseResult: Equatable {
    var id: String?
    var text: String
}

private struct OpenAIResponsesRequest: Encodable {
    var model: String
    var instructions: String
    var input: String
    var previousResponseID: String?

    enum CodingKeys: String, CodingKey {
        case model
        case instructions
        case input
        case previousResponseID = "previous_response_id"
    }
}

private struct OpenAIResponsesResponse: Decodable {
    var id: String?
    var outputText: String?
    var output: [OutputItem]?

    var displayText: String? {
        if let outputText { return outputText }
        return output?
            .flatMap { $0.content ?? [] }
            .compactMap(\.text)
            .joined(separator: "\n")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case outputText = "output_text"
        case output
    }

    struct OutputItem: Decodable {
        var content: [ContentItem]?
    }

    struct ContentItem: Decodable {
        var text: String?
    }
}

private struct OpenAIErrorEnvelope: Decodable {
    var error: OpenAIError

    struct OpenAIError: Decodable {
        var message: String
    }
}
