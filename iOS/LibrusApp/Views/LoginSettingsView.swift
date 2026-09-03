import SwiftUI

struct LoginSettingsView: View {
    @StateObject private var watchManager = WatchConnectivityManager.shared

    @AppStorage("server_url") private var serverUrl: String = "https://librus.yourdomain.com"
    @AppStorage("synergia_login") private var login: String = ""
    @AppStorage("saved_token") private var savedToken: String = ""
    @AppStorage("student_name") private var studentName: String = ""

    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var alertMessage: String?
    @State private var showAlert: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Serwer Ubuntu")) {
                    TextField("Adres serwera (HTTPS)", text: $serverUrl)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Section(header: Text("Konto Librus Synergia")) {
                    TextField("Login (np. 1234567u)", text: $login)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    SecureField("Hasło", text: $password)
                }

                Section {
                    Button(action: performLogin) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text("Zaloguj i połącz z Apple Watch")
                                .bold()
                            Spacer()
                        }
                    }
                    .disabled(isLoading || serverUrl.isEmpty || login.isEmpty || password.isEmpty)
                }

                if !studentName.isEmpty {
                    Section(header: Text("Status profilu")) {
                        HStack {
                            Text("Uczeń:")
                            Spacer()
                            Text(studentName).bold()
                        }
                        HStack {
                            Text("Status sesji:")
                            Spacer()
                            Text("Aktywna")
                                .foregroundColor(.green)
                        }
                    }
                }

                Section(header: Text("Status Apple Watch")) {
                    HStack {
                        Text("Zegarek sparowany:")
                        Spacer()
                        Text(watchManager.isPaired ? "Tak" : "Nie")
                            .foregroundColor(watchManager.isPaired ? .green : .orange)
                    }

                    HStack {
                        Text("Aplikacja zainstalowana na Watch:")
                        Spacer()
                        Text(watchManager.isWatchAppInstalled ? "Tak" : "Nie")
                            .foregroundColor(watchManager.isWatchAppInstalled ? .green : .red)
                    }

                    HStack {
                        Text("Status synchronizacji:")
                        Spacer()
                        Text(watchManager.syncStatus)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if !savedToken.isEmpty {
                        Button("Wyślij konfigurację na Apple Watch ponownie") {
                            watchManager.sendCredentialsToWatch(serverUrl: serverUrl, apiToken: savedToken)
                        }
                        .font(.footnote)
                    }
                }
            }
            .navigationTitle("Librus Sync")
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Powiadomienie"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func performLogin() {
        isLoading = true
        Task {
            do {
                let res = try await APIService.shared.login(serverUrl: serverUrl, login: login, pass: password)
                await MainActor.run {
                    self.savedToken = res.token
                    if let name = res.studentName {
                        self.studentName = name
                    }
                    // Send to paired Apple Watch immediately
                    watchManager.sendCredentialsToWatch(serverUrl: serverUrl, apiToken: res.token)

                    self.alertMessage = "Pomyślnie połączono z Librus Synergia! Dane przekazane do Apple Watch."
                    self.showAlert = true
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.alertMessage = "Błąd: \(error.localizedDescription)"
                    self.showAlert = true
                    self.isLoading = false
                }
            }
        }
    }
}
