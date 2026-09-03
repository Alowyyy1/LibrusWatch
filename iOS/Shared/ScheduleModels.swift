import Foundation
import SwiftUI

// MARK: - Lesson Model
public struct Lesson: Identifiable, Codable, Hashable {
    public let id: String
    public let lessonNumber: Int
    public let subject: String
    public let originalSubject: String?
    public let timeStart: String
    public let timeEnd: String
    public let room: String?
    public let originalRoom: String?
    public let teacher: String?
    public let originalTeacher: String?
    public let color: String
    public let isSubstitution: Bool
    public let isCancelled: Bool
    public let substitutionType: String?
    public let substitutionNote: String?

    enum CodingKeys: String, CodingKey {
        case id
        case lessonNumber = "lesson_number"
        case subject
        case originalSubject = "original_subject"
        case timeStart = "time_start"
        case timeEnd = "time_end"
        case room
        case originalRoom = "original_room"
        case teacher
        case originalTeacher = "original_teacher"
        case color
        case isSubstitution = "is_substitution"
        case isCancelled = "is_cancelled"
        case substitutionType = "substitution_type"
        case substitutionNote = "substitution_note"
    }

    public var swiftUIColor: Color {
        Color(hex: color) ?? Color(red: 0.14, green: 0.23, blue: 0.71)
    }
}

// MARK: - Day Schedule
public struct DaySchedule: Identifiable, Codable, Hashable {
    public var id: String { dateStr }
    public let dayName: String
    public let dayShort: String
    public let dateStr: String
    public let lessons: [Lesson]

    enum CodingKeys: String, CodingKey {
        case dayName = "day_name"
        case dayShort = "day_short"
        case dateStr = "date_str"
        case lessons
    }
}

// MARK: - Week Schedule Response
public struct WeekScheduleResponse: Codable {
    public let weekStart: String
    public let weekEnd: String
    public let serverTime: String
    public let lastSynced: String
    public let days: [DaySchedule]

    enum CodingKeys: String, CodingKey {
        case weekStart = "week_start"
        case weekEnd = "week_end"
        case serverTime = "server_time"
        case lastSynced = "last_synced"
        case days
    }
}

// MARK: - Today Lesson Response
public struct TodayLessonResponse: Codable {
    public let serverTime: String
    public let currentLesson: Lesson?
    public let nextLesson: Lesson?
    public let remainingLessonsCount: Int

    enum CodingKeys: String, CodingKey {
        case serverTime = "server_time"
        case currentLesson = "current_lesson"
        case nextLesson = "next_lesson"
        case remainingLessonsCount = "remaining_lessons_count"
    }
}

// MARK: - Color Hex Extension
public extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r, g, b: Double
        if hexSanitized.count == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
        } else {
            return nil
        }
        self.init(red: r, green: g, blue: b)
    }
}
