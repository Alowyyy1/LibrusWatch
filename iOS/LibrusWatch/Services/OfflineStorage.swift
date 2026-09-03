import Foundation

class OfflineStorage {
    static let shared = OfflineStorage()
    private let defaults = UserDefaults.standard

    private let keySchedule = "cached_schedule_v1"
    private let keyServerUrl = "server_base_url"
    private let keyApiToken = "api_token"
    private let keyLastSync = "last_sync_timestamp"

    // MARK: - Server Configuration
    var serverUrl: String {
        get { defaults.string(forKey: keyServerUrl) ?? "http://localhost:8000" }
        set { defaults.set(newValue, forKey: keyServerUrl) }
    }

    var apiToken: String? {
        get { defaults.string(forKey: keyApiToken) }
        set { defaults.set(newValue, forKey: keyApiToken) }
    }

    var lastSyncText: String {
        get { defaults.string(forKey: keyLastSync) ?? "" }
        set { defaults.set(newValue, forKey: keyLastSync) }
    }

    // MARK: - Schedule Cache
    func saveSchedule(_ schedule: WeekScheduleResponse) {
        if let encoded = try? JSONEncoder().encode(schedule) {
            defaults.set(encoded, forKey: keySchedule)
            
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm, dd.MM"
            lastSyncText = formatter.string(from: Date())
        }
    }

    func loadSchedule() -> WeekScheduleResponse? {
        guard let data = defaults.data(forKey: keySchedule) else { return nil }
        return try? JSONDecoder().decode(WeekScheduleResponse.self, from: data)
    }
}
