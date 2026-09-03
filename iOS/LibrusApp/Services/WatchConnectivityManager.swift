import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var isWatchAppInstalled: Bool = false
    @Published var isPaired: Bool = false
    @Published var isReachable: Bool = false
    @Published var syncStatus: String = "Oczekiwanie"

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func sendCredentialsToWatch(serverUrl: String, apiToken: String) {
        guard WCSession.isSupported() else {
            syncStatus = "WatchConnectivity nie jest wspierane"
            return
        }

        let context: [String: Any] = [
            "server_url": serverUrl,
            "api_token": apiToken
        ]

        do {
            try WCSession.default.updateApplicationContext(context)
            syncStatus = "Konfiguracja przesłana do Apple Watch!"
        } catch {
            print("Error sending context: \(error.localizedDescription)")
            // Fallback to transferUserInfo
            WCSession.default.transferUserInfo(context)
            syncStatus = "Wysłano w kolejce do zegarka"
        }
    }

    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
