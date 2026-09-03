import SwiftUI

struct LessonDetailSheet: View {
    let lesson: Lesson
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Header badge
                HStack {
                    Text("Lekcja \(lesson.lessonNumber)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(lesson.timeStart) - \(lesson.timeEnd)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                // Main Subject Title
                Text(lesson.subject)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)

                Divider()

                // Room Info
                if let room = lesson.room {
                    HStack {
                        Image(systemName: "door.left.hand.open")
                            .foregroundColor(.blue)
                        Text("Sala:")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        if let origRoom = lesson.originalRoom, origRoom != room {
                            Text(origRoom)
                                .strikethrough()
                                .foregroundColor(.secondary)
                            Text("→")
                        }
                        Text(room)
                            .font(.system(size: 13, weight: .bold))
                    }
                }

                // Teacher Info
                if let teacher = lesson.teacher {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.purple)
                        Text("Nauczyciel:")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        if let origTeacher = lesson.originalTeacher, origTeacher != teacher {
                            Text(origTeacher)
                                .strikethrough()
                                .foregroundColor(.secondary)
                            Text("→")
                        }
                        Text(teacher)
                            .font(.system(size: 13, weight: .bold))
                    }
                }

                // Substitution Reason / Note
                if lesson.isSubstitution {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("Szczegóły zastępstwa:")
                                .font(.system(size: 12, weight: .bold))
                        }
                        if let note = lesson.substitutionNote, !note.isEmpty {
                            Text(note)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(6)
                        }
                    }
                }

                if lesson.isCancelled {
                    HStack {
                        Image(systemName: "xmark.octagon.fill")
                            .foregroundColor(.red)
                        Text("Lekcja została odwołana!")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.red)
                    }
                }

                Button("Zamknij") {
                    dismiss()
                }
                .padding(.top, 8)
                .buttonStyle(.bordered)
                .tint(.gray)
            }
            .padding()
        }
    }
}
