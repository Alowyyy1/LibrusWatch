import SwiftUI

struct DaySelectorView: View {
    let days: [DaySchedule]
    @Binding var selectedIndex: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(days.indices, id: \.self) { idx in
                let isSelected = selectedIndex == idx
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedIndex = idx
                    }
                }) {
                    Text(days[idx].dayShort)
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(
                            isSelected ? Color.blue : Color.gray.opacity(0.15)
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}
