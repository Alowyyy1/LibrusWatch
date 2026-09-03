import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(String)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Nieprawidłowy adres serwera"
        case .unauthorized:
            return "Brak autoryzacji. Zaloguj się w aplikacji na iPhone."
        case .serverError(let msg):
            return msg
        case .decodingError:
            return "Błąd dekodowania odpowiedzi z serwera"
        }
    }
}

class WatchAPIManager {
    static let shared = WatchAPIManager()

    func fetchWeekSchedule(forceSync: Bool = false) async throws -> WeekScheduleResponse {
        let storage = OfflineStorage.shared
        guard let token = storage.apiToken, !token.isEmpty else {
            throw APIError.unauthorized
        }

        var baseUrl = storage.serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if baseUrl.hasSuffix("/") {
            baseUrl.removeLast()
        }

        let endpoint = forceSync ? "/api/schedule/sync" : "/api/schedule/week"
        guard let url = URL(string: "\(baseUrl)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = forceSync ? "POST" : "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpRes = response as? HTTPURLResponse else {
            throw APIError.serverError("Nieprawidłowa odpowiedź serwera")
        }

        if httpRes.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard httpRes.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Błąd serwera (\(httpRes.statusCode))"
            throw APIError.serverError(errorMsg)
        }

        do {
            let decoded = try JSONDecoder().decode(WeekScheduleResponse.self, from: data)
            storage.saveSchedule(decoded)
            return decoded
        } catch {
            print("Decoding error: \(error)")
            throw APIError.decodingError
        }
    }
}
