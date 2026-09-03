import WidgetKit
import SwiftUI

struct ScheduleEntry: TimelineEntry {
    let date: Date
    let lesson: Lesson?
    let nextLesson: Lesson?
}

struct LibrusTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(
            date: Date(),
            lesson: Lesson(
                id: "placeholder",
                lessonNumber: 1,
                subject: "Historia",
                originalSubject: nil,
                timeStart: "08:00",
                timeEnd: "08:45",
                room: "s. 204",
                originalRoom: nil,
                teacher: "Kowalski J.",
                originalTeacher: nil,
                color: "#1D3BB5",
                isSubstitution: false,
                isCancelled: false,
                substitutionType: nil,
                substitutionNote: nil
            ),
            nextLesson: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        let entry = getCurrentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let entry = getCurrentEntry()
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func getCurrentEntry() -> ScheduleEntry {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: now)
        formatter.dateFormat = "HH:mm"
        let timeStr = formatter.string(from: now)

        guard let sched = OfflineStorage.shared.loadSchedule() else {
            return ScheduleEntry(date: now, lesson: nil, nextLesson: nil)
        }

        let today = sched.days.first(where: { $0.dateStr == todayStr })
        guard let lessons = today?.lessons else {
            return ScheduleEntry(date: now, lesson: nil, nextLesson: nil)
        }

        var cur: Lesson? = nil
        var nxt: Lesson? = nil

        for l in lessons {
            if l.timeStart <= timeStr && timeStr <= l.timeEnd {
                cur = l
            } else if l.timeStart > timeStr && nxt == nil {
                nxt = l
            }
        }

        return ScheduleEntry(date: now, lesson: cur, nextLesson: nxt)
    }
}

struct LibrusComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: ScheduleEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                if let lesson = entry.lesson ?? entry.nextLesson {
                    HStack {
                        Text(entry.lesson != nil ? "TERAZ:" : "NASTĘPNY:")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        if let room = lesson.room {
                            Text(room)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.blue)
                        }
                    }
                    Text(lesson.subject)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text("\(lesson.timeStart) - \(lesson.timeEnd)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                } else {
                    Text("Librus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Koniec lekcji na dziś")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

        case .accessoryInline:
            if let lesson = entry.lesson ?? entry.nextLesson {
                Text("\(lesson.subject) \(lesson.room ?? "") (\(lesson.timeStart))")
            } else {
                Text("Librus: Brak lekcji")
            }

        default:
            VStack {
                Image(systemName: "calendar.badge.clock")
                if let room = (entry.lesson ?? entry.nextLesson)?.room {
                    Text(room)
                        .font(.system(size: 8, weight: .bold))
                }
            }
        }
    }
}

struct LibrusComplication: Widget {
    let kind: String = "LibrusComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LibrusTimelineProvider()) { entry in
            LibrusComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Plan Librus")
        .description("Aktualna lub najbliższa lekcja i sala")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCorner, .accessoryCircular])
    }
}
