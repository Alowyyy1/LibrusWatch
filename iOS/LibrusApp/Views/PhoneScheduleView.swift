import SwiftUI

struct PhoneScheduleView: View {
    @AppStorage("server_url") private var serverUrl: String = ""
    @AppStorage("saved_token") private var savedToken: String = ""

    @State private var schedule: WeekScheduleResponse?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var selectedDayIndex: Int = 0

    var body: some View {
        NavigationView {
            VStack {
                if savedToken.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 44))
                            .foregroundColor(.blue)
                        Text("Zaloguj się najpierw w zakładce Ustawienia")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if isLoading {
                    ProgressView("Pobieranie planu z Librusa...")
                } else if let schedule = schedule {
                    // Day Picker
                    Picker("Dzień", selection: $selectedDayIndex) {
                        ForEach(schedule.days.indices, id: \.self) { idx in
                            Text(schedule.days[idx].dayShort).tag(idx)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    // Lessons List
                    if selectedDayIndex < schedule.days.count {
                        let currentDay = schedule.days[selectedDayIndex]
                        List {
                            ForEach(currentDay.lessons) { lesson in
                                HStack(spacing: 12) {
                                    // White bar for substitution
                                    if lesson.isSubstitution {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.orange)
                                            .frame(width: 4)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(lesson.subject)
                                            .font(.headline)
                                            .foregroundColor(lesson.isCancelled ? .secondary : .primary)

                                        HStack {
                                            Text("\(lesson.timeStart) - \(lesson.timeEnd)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)

                                            if let room = lesson.room {
                                                Text("• \(room)")
                                                    .font(.subheadline)
                                                    .bold()
                                            }

                                            if let teacher = lesson.teacher {
                                                Text("• \(teacher)")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        if let note = lesson.substitutionNote {
                                            Text(note)
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 8) {
                        Text("Błąd: \(error)").foregroundColor(.red)
                        Button("Spróbuj ponownie") {
                            loadSchedule()
                        }
                    }
                }
            }
            .navigationTitle("Plan lekcji")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadSchedule) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(savedToken.isEmpty || isLoading)
                }
            }
            .onAppear {
                if schedule == nil && !savedToken.isEmpty {
                    loadSchedule()
                }
            }
        }
    }

    private func loadSchedule() {
        guard !savedToken.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let res = try await APIService.shared.fetchWeekSchedule(serverUrl: serverUrl, token: savedToken)
                await MainActor.run {
                    self.schedule = res
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
