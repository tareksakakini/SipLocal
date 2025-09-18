import SwiftUI

struct BusinessHoursView: View {
    let businessHoursInfo: BusinessHoursInfo
    @State private var isExpanded = false
    
    private let dayNames = [
        "MON": "Monday",
        "TUE": "Tuesday", 
        "WED": "Wednesday",
        "THU": "Thursday",
        "FRI": "Friday",
        "SAT": "Saturday",
        "SUN": "Sunday"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with open/closed status
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.primary)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("Business Hours")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Open/Closed indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(businessHoursInfo.isCurrentlyOpen ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(businessHoursInfo.isCurrentlyOpen ? "Open" : "Closed")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(businessHoursInfo.isCurrentlyOpen ? .green : .red)
                    }
                    
                    // Chevron icon
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Weekly hours dropdown
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(dayNames.keys.sorted()), id: \.self) { dayKey in
                        if let periods = businessHoursInfo.weeklyHours[dayKey] {
                            DayHoursRow(
                                dayName: dayNames[dayKey] ?? dayKey,
                                periods: periods,
                                isToday: isToday(dayKey)
                            )
                        }
                    }
                }
                .padding(.top, 8)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func isToday(_ dayKey: String) -> Bool {
        let today = Calendar.current.component(.weekday, from: Date())
        let dayMapping = ["SUN": 1, "MON": 2, "TUE": 3, "WED": 4, "THU": 5, "FRI": 6, "SAT": 7]
        return dayMapping[dayKey] == today
    }
}

struct DayHoursRow: View {
    let dayName: String
    let periods: [BusinessHoursPeriod]
    let isToday: Bool
    
    var body: some View {
        HStack {
            Text(dayName)
                .font(.subheadline)
                .fontWeight(isToday ? .semibold : .medium)
                .foregroundColor(isToday ? .primary : .secondary)
                .frame(width: 90, alignment: .leading)
            
            if isToday {
                Text("Today")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                ForEach(periods, id: \.startTime) { period in
                    Text("\(formatTime(period.startTime)) - \(formatTime(period.endTime))")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(isToday ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
    
    private func formatTime(_ timeString: String) -> String {
        // Convert 24-hour format to 12-hour format
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        if let date = formatter.date(from: timeString) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date).lowercased()
        }
        
        return timeString
    }
}

struct BusinessHoursUnavailableView: View {
    var body: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(.secondary)
                .font(.system(size: 16, weight: .medium))
            
            Text("Business Hours")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("Not Available")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(6)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    let sampleHours = BusinessHoursInfo(
        weeklyHours: [
            "MON": [BusinessHoursPeriod(startTime: "08:00", endTime: "17:00")],
            "TUE": [BusinessHoursPeriod(startTime: "08:00", endTime: "17:00")],
            "WED": [BusinessHoursPeriod(startTime: "08:00", endTime: "17:00")],
            "THU": [BusinessHoursPeriod(startTime: "08:00", endTime: "17:00")],
            "FRI": [BusinessHoursPeriod(startTime: "08:00", endTime: "18:00")],
            "SAT": [BusinessHoursPeriod(startTime: "09:00", endTime: "16:00")],
            "SUN": [BusinessHoursPeriod(startTime: "10:00", endTime: "15:00")]
        ],
        isCurrentlyOpen: true
    )
    
    return BusinessHoursView(businessHoursInfo: sampleHours)
        .padding()
        .background(Color(.systemGroupedBackground))
} 