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
        VStack(alignment: .leading, spacing: 8) {
            // Header with open/closed status
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.primary)
                
                Text("Business Hours")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
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
                
                // Dropdown arrow
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
            
            // Weekly hours dropdown
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(dayNames.keys.sorted()), id: \.self) { dayKey in
                        if let periods = businessHoursInfo.weeklyHours[dayKey] {
                            HStack {
                                Text(dayNames[dayKey] ?? dayKey)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                
                                Text(formatPeriods(periods))
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                        } else {
                            HStack {
                                Text(dayNames[dayKey] ?? dayKey)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                
                                Text("Closed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatPeriods(_ periods: [BusinessHoursPeriod]) -> String {
        return periods.map { period in
            "\(period.startTime) - \(period.endTime)"
        }.joined(separator: ", ")
    }
}

struct BusinessHoursUnavailableView: View {
    var body: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(.secondary)
            
            Text("Business hours not available")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack {
        BusinessHoursView(businessHoursInfo: BusinessHoursInfo(
            weeklyHours: [
                "MON": [BusinessHoursPeriod(startTime: "09:00", endTime: "17:00")],
                "TUE": [BusinessHoursPeriod(startTime: "09:00", endTime: "17:00")],
                "WED": [BusinessHoursPeriod(startTime: "09:00", endTime: "17:00")],
                "THU": [BusinessHoursPeriod(startTime: "09:00", endTime: "17:00")],
                "FRI": [BusinessHoursPeriod(startTime: "09:00", endTime: "18:00")],
                "SAT": [BusinessHoursPeriod(startTime: "10:00", endTime: "16:00")],
                "SUN": []
            ],
            isCurrentlyOpen: true
        ))
        
        BusinessHoursUnavailableView()
    }
    .padding()
} 