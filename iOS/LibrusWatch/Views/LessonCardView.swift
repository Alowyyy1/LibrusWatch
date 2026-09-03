import SwiftUI

struct LessonCardView: View {
    let lesson: Lesson
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // White vertical accent bar for substitutions (matches screenshot)
                if lesson.isSubstitution {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 4)
                        .padding(.vertical, 4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Subject Name
                    HStack {
                        Text(lesson.subject)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        Spacer()

                        // Room badge if available
                        if let room = lesson.room {
                            Text(room)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.25))
                                .cornerRadius(4)
                        }
                    }

                    // Time Interval (e.g. 08:00 - 08:45)
                    HStack(spacing: 6) {
                        Text("\(lesson.timeStart) - \(lesson.timeEnd)")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))

                        if lesson.isCancelled {
                            Text("ODWOŁANA")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.white)
                                .cornerRadius(3)
                        } else if lesson.isSubstitution {
                            Text("ZASTĘPSTWO")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(3)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, lesson.isSubstitution ? 4 : 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(lesson.swiftUIColor)
            .cornerRadius(10)
            .opacity(lesson.isCancelled ? 0.6 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
