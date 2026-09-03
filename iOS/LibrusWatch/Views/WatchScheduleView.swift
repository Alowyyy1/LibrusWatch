import SwiftUI
import WatchKit

struct WatchScheduleView: View {
    @StateObject private var sessionManager = WatchSessionManager.shared
    @State private var schedule: WeekScheduleResponse?
    @State private var selectedDayIndex: Int = 0
    @State private var selectedLesson: Lesson?
    @State private var isSyncing: Bool = false
    @State private var errorMessage: String?
    @State private var lastSyncedText: String = ""

    var body: some View {
        Group {
            if !sessionManager.isConfigured && schedule == nil {
                // Setup prompt view
                VStack(spacing: 8) {
                    Image(systemName: "iphone.and.arrow.forward")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)

                    Text("Wymagana konfiguracja")
                        .font(.system(size: 13, weight: .bold))
                        .multilineTextAlignment(.center)

                    Text("Otwórz aplikację na iPhone i zaloguj się do Librusa.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }
                .padding()
            } else if let schedule = schedule, !schedule.days.isEmpty {
                // Main Schedule View
                VStack(spacing: 0) {
                    // Top Day selector (Pon, Wt, Śr, Czw, Pt)
                    DaySelectorView(days: schedule.days, selectedIndex: $selectedDayIndex)
                        .background(Color.black.opacity(0.4))

                    // Horizontal swipeable days
                    TabView(selection: $selectedDayIndex) {
                        ForEach(schedule.days.indices, id: \.self) { idx in
                            let day = schedule.days[idx]
                            TimelineDayView(
                                day: day,
                                isToday: checkIfToday(day.dateStr),
                                onSelectLesson: { lesson in
                                    selectedLesson = lesson
                                },
                                onSync: performSync,
                                isSyncing: isSyncing,
                                lastSyncedText: lastSyncedText
                            )
                            .tag(idx)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            } else {
                // Initial loading state
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Ładowanie planu...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .sheet(item: $selectedLesson) { lesson in
            LessonDetailSheet(lesson: lesson)
        }
        .onAppear {
            loadInitialData()
        }
    }

    private func loadInitialData() {
        // 1. Instant load from local cache
        if let cached = OfflineStorage.shared.loadSchedule() {
            self.schedule = cached
            self.lastSyncedText = OfflineStorage.shared.lastSyncText
            selectCurrentWeekday(days: cached.days)
        }

        // 2. Background fresh fetch if configured
        if sessionManager.isConfigured {
            Task {
                await fetchSchedule(force: false)
            }
        }
    }

    private func performSync() {
        WKInterfaceDevice.current().play(.click)
        Task {
            await fetchSchedule(force: true)
        }
    }

    @MainActor
    private func fetchSchedule(force: Bool) async {
        isSyncing = true
        errorMessage = nil

        do {
            let res = try await WatchAPIManager.shared.fetchWeekSchedule(forceSync: force)
            self.schedule = res
            self.lastSyncedText = OfflineStorage.shared.lastSyncText
            WKInterfaceDevice.current().play(.success)
        } catch {
            self.errorMessage = error.localizedDescription
            WKInterfaceDevice.current().play(.failure)
        }

        isSyncing = false
    }

    private func checkIfToday(_ dateStr: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date()) == dateStr
    }

    private func selectCurrentWeekday(days: [DaySchedule]) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())

        if let idx = days.firstIndex(where: { $0.dateStr == todayStr }) {
            selectedDayIndex = idx
        } else {
            let weekday = Calendar.current.component(.weekday, from: Date())
            // Apple Calendar: 1=Sunday, 2=Monday, 3=Tuesday, 4=Wednesday, 5=Thursday, 6=Friday, 7=Saturday
            let mappedIdx = max(0, min(days.count - 1, weekday - 2))
            selectedDayIndex = mappedIdx
        }
    }
}
