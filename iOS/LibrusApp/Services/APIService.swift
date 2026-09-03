import Foundation

struct LoginResponseData: Codable {
    let success: Bool
    let token: String
    let studentName: String?
    let message: String

    enum CodingKeys: String, CodingKey {
        case success
        case token
        case studentName = "student_name"
        case message
    }
}

class APIService {
    static let shared = APIService()

    func login(serverUrl: String, login: String, pass: String) async throws -> LoginResponseData {
        var cleanUrl = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanUrl.hasSuffix("/") {
            cleanUrl.removeLast()
        }

        guard let url = URL(string: "\(cleanUrl)/api/auth/login") else {
            throw NSError(domain: "LibrusApp", code: 400, userInfo: [NSLocalizedDescriptionKey: "Nieprawidłowy adres URL serwera"])
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let bodyDict = ["username": login, "password": pass]
        req.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let httpRes = response as? HTTPURLResponse else {
            throw NSError(domain: "LibrusApp", code: 500, userInfo: [NSLocalizedDescriptionKey: "Błąd serwera"])
        }

        guard httpRes.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Błąd autoryzacji (\(httpRes.statusCode))"
            throw NSError(domain: "LibrusApp", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText])
        }

        return try JSONDecoder().decode(LoginResponseData.self, from: data)
    }

    func fetchWeekSchedule(serverUrl: String, token: String) async throws -> WeekScheduleResponse {
        var cleanUrl = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanUrl.hasSuffix("/") {
            cleanUrl.removeLast()
        }

        guard let url = URL(string: "\(cleanUrl)/api/schedule/week") else {
            throw NSError(domain: "LibrusApp", code: 400, userInfo: [NSLocalizedDescriptionKey: "Nieprawidłowy URL"])
        }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw NSError(domain: "LibrusApp", code: 500, userInfo: [NSLocalizedDescriptionKey: "Błąd pobierania planu"])
        }

        return try JSONDecoder().decode(WeekScheduleResponse.self, from: data)
    }
}
