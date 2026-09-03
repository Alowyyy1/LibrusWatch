import Foundation
import WatchConnectivity

class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    @Published var isConfigured: Bool = false
    @Published var statusMessage: String = ""

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        checkConfiguration()
    }

    func checkConfiguration() {
        isConfigured = OfflineStorage.shared.apiToken != nil && !OfflineStorage.shared.apiToken!.isEmpty
    }

    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation error: \(error.localizedDescription)")
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            self.handleContext(applicationContext)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        DispatchQueue.main.async {
            self.handleContext(userInfo)
        }
    }

    private func handleContext(_ dict: [String: Any]) {
        if let url = dict["server_url"] as? String {
            OfflineStorage.shared.serverUrl = url
        }
        if let token = dict["api_token"] as? String {
            OfflineStorage.shared.apiToken = token
            self.isConfigured = true
            self.statusMessage = "Dane zsynchronizowane z iPhone"

            // Auto-fetch schedule
            Task {
                try? await WatchAPIManager.shared.fetchWeekSchedule(forceSync: true)
            }
        }
    }
}
