import SwiftUI

struct TimelineDayView: View {
    let day: DaySchedule
    let isToday: Bool
    let onSelectLesson: (Lesson) -> Void
    let onSync: () -> Void
    let isSyncing: Bool
    let lastSyncedText: String

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Today badge
                if isToday {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("Dzisiaj, \(day.dateStr)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                }

                // If no lessons
                if day.lessons.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.yellow)
                            .padding(.top, 20)
                        Text("Brak zaplanowanych lekcji")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
                } else {
                    // Lessons list with Librus-like time markers
                    VStack(spacing: 6) {
                        ForEach(day.lessons) { lesson in
                            HStack(alignment: .top, spacing: 6) {
                                // Left time marker (e.g. 08:00)
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(lesson.timeStart)
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.gray)
                                    
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 1, height: 26)
                                        .padding(.trailing, 4)
                                    
                                    Text(lesson.timeEnd)
                                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                                        .foregroundColor(.gray.opacity(0.7))
                                }
                                .frame(width: 36)

                                // Main Lesson Card
                                LessonCardView(lesson: lesson) {
                                    onSelectLesson(lesson)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }

                Divider()
                    .padding(.vertical, 4)

                // Sync button at the very bottom (matches user request)
                VStack(spacing: 4) {
                    Button(action: onSync) {
                        HStack(spacing: 6) {
                            if isSyncing {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            Text(isSyncing ? "Synchronizacja..." : "Sync")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isSyncing)
                    .buttonStyle(PlainButtonStyle())

                    if !lastSyncedText.isEmpty {
                        Text("Ost. sync: \(lastSyncedText)")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .padding(.top, 4)
        }
    }
}
