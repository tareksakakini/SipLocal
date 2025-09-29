import SwiftUI

/**
 * BusinessHoursView - Displays business hours information with expandable weekly schedule.
 *
 * ## Features
 * - **Expandable Interface**: Tap to show/hide weekly hours
 * - **Status Indicator**: Visual open/closed status with color coding
 * - **Today Highlighting**: Current day is highlighted with special styling
 * - **Time Formatting**: 24-hour to 12-hour time conversion
 * - **Accessibility**: Full VoiceOver support with proper labels and hints
 *
 * ## Usage
 * ```swift
 * BusinessHoursView(businessHoursInfo: hoursInfo)
 * ```
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */
struct BusinessHoursView: View {
    
    // MARK: - Properties
    
    let businessHoursInfo: BusinessHoursInfo
    @State private var isExpanded = false
    
    // MARK: - Design System
    
    enum Design {
        // Layout
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 2
        static let shadowOpacity: Double = 0.05
        static let borderWidth: CGFloat = 1
        
        // Spacing
        static let headerPadding: CGFloat = 16
        static let headerVerticalPadding: CGFloat = 12
        static let contentSpacing: CGFloat = 8
        static let rowSpacing: CGFloat = 0
        static let dayRowPadding: CGFloat = 8
        static let dayRowHorizontalPadding: CGFloat = 16
        
        // Animation
        static let expandAnimation = Animation.easeInOut(duration: 0.3)
        static let chevronAnimation = Animation.easeInOut(duration: 0.2)
        
        // Colors
        static let openColor = Color.green
        static let closedColor = Color.red
        static let todayColor = Color.blue
        static let todayBackgroundOpacity: Double = 0.05
        static let todayBadgeOpacity: Double = 0.1
        
        // Typography
        static let headerFont = Font.subheadline.weight(.medium)
        static let statusFont = Font.caption.weight(.medium)
        static let dayFont = Font.subheadline.weight(.medium)
        static let todayFont = Font.subheadline.weight(.semibold)
        static let timeFont = Font.subheadline
        static let todayBadgeFont = Font.caption.weight(.medium)
        
        // Icons
        static let clockIcon = "clock"
        static let chevronUpIcon = "chevron.up"
        static let chevronDownIcon = "chevron.down"
        static let iconSize: CGFloat = 16
        static let chevronSize: CGFloat = 12
        
        // Status Indicator
        static let statusDotSize: CGFloat = 8
        static let statusSpacing: CGFloat = 4
        
        // Day Layout
        static let dayNameWidth: CGFloat = 90
        static let todayBadgePadding: CGFloat = 6
        static let todayBadgeVerticalPadding: CGFloat = 2
        static let todayBadgeCornerRadius: CGFloat = 4
        static let dayRowCornerRadius: CGFloat = 8
        
        // Time Formatting
        static let timeSpacing: CGFloat = 2
    }
    
    // MARK: - Day Names Mapping
    
    private let dayNames = [
        "MON": "Monday",
        "TUE": "Tuesday", 
        "WED": "Wednesday",
        "THU": "Thursday",
        "FRI": "Friday",
        "SAT": "Saturday",
        "SUN": "Sunday"
    ]
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: Design.rowSpacing) {
            headerSection
            expandedContentSection
        }
        .background(Color(.systemBackground))
        .cornerRadius(Design.cornerRadius)
        .shadow(
            color: Color.black.opacity(Design.shadowOpacity),
            radius: Design.shadowRadius,
            x: 0,
            y: 1
        )
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        Button(action: toggleExpansion) {
            HStack {
                clockIcon
                titleText
                Spacer()
                statusIndicator
                chevronIcon
            }
            .padding(.vertical, Design.headerVerticalPadding)
            .padding(.horizontal, Design.headerPadding)
            .background(Color(.systemBackground))
            .cornerRadius(Design.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Design.cornerRadius)
                    .stroke(Color(.systemGray5), lineWidth: Design.borderWidth)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Business Hours")
        .accessibilityHint(isExpanded ? "Tap to collapse hours" : "Tap to expand hours")
        .accessibilityValue(businessHoursInfo.isCurrentlyOpen ? "Open" : "Closed")
    }
    
    // MARK: - Header Components
    
    private var clockIcon: some View {
        Image(systemName: Design.clockIcon)
            .foregroundColor(.primary)
            .font(.system(size: Design.iconSize, weight: .medium))
            .accessibilityHidden(true)
    }
    
    private var titleText: some View {
        Text("Business Hours")
            .font(Design.headerFont)
            .foregroundColor(.primary)
    }
    
    private var statusIndicator: some View {
        HStack(spacing: Design.statusSpacing) {
            Circle()
                .fill(statusColor)
                .frame(width: Design.statusDotSize, height: Design.statusDotSize)
            
            Text(statusText)
                .font(Design.statusFont)
                .foregroundColor(statusColor)
        }
        .accessibilityLabel("Status: \(statusText)")
    }
    
    private var chevronIcon: some View {
        Image(systemName: isExpanded ? Design.chevronUpIcon : Design.chevronDownIcon)
            .font(.system(size: Design.chevronSize, weight: .medium))
            .foregroundColor(.secondary)
            .animation(Design.chevronAnimation, value: isExpanded)
            .accessibilityHidden(true)
    }
    
    // MARK: - Expanded Content Section
    
    private var expandedContentSection: some View {
        Group {
            if isExpanded {
                VStack(spacing: Design.rowSpacing) {
                    ForEach(sortedDayKeys, id: \.self) { dayKey in
                        if let periods = businessHoursInfo.weeklyHours[dayKey] {
                            DayHoursRow(
                                dayName: dayNames[dayKey] ?? dayKey,
                                periods: periods,
                                isToday: isToday(dayKey)
                            )
                        }
                    }
                }
                .padding(.top, Design.contentSpacing)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        businessHoursInfo.isCurrentlyOpen ? Design.openColor : Design.closedColor
    }
    
    private var statusText: String {
        businessHoursInfo.isCurrentlyOpen ? "Open" : "Closed"
    }
    
    private var sortedDayKeys: [String] {
        Array(dayNames.keys.sorted())
    }
    
    // MARK: - Actions
    
    private func toggleExpansion() {
        withAnimation(Design.expandAnimation) {
            isExpanded.toggle()
        }
    }
    
    private func isToday(_ dayKey: String) -> Bool {
        let today = Calendar.current.component(.weekday, from: Date())
        let dayMapping = ["SUN": 1, "MON": 2, "TUE": 3, "WED": 4, "THU": 5, "FRI": 6, "SAT": 7]
        return dayMapping[dayKey] == today
    }
}

/**
 * DayHoursRow - Displays individual day's business hours with today highlighting.
 *
 * ## Features
 * - **Today Highlighting**: Current day gets special styling and "Today" badge
 * - **Time Formatting**: Converts 24-hour format to 12-hour format
 * - **Accessibility**: Full VoiceOver support with proper labels
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */
struct DayHoursRow: View {
    
    // MARK: - Properties
    
    let dayName: String
    let periods: [BusinessHoursPeriod]
    let isToday: Bool
    
    // MARK: - Design System
    
    enum Design {
        // Layout
        static let cornerRadius: CGFloat = 8
        static let dayNameWidth: CGFloat = 90
        
        // Spacing
        static let verticalPadding: CGFloat = 8
        static let horizontalPadding: CGFloat = 16
        static let timeSpacing: CGFloat = 2
        static let todayBadgePadding: CGFloat = 6
        static let todayBadgeVerticalPadding: CGFloat = 2
        
        // Colors
        static let todayColor = Color.blue
        static let todayBackgroundOpacity: Double = 0.05
        static let todayBadgeOpacity: Double = 0.1
        
        // Typography
        static let dayFont = Font.subheadline.weight(.medium)
        static let todayFont = Font.subheadline.weight(.semibold)
        static let timeFont = Font.subheadline
        static let todayBadgeFont = Font.caption.weight(.medium)
        
        // Today Badge
        static let todayBadgeCornerRadius: CGFloat = 4
        static let todayBadgeText = "Today"
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack {
            dayNameSection
            todayBadgeSection
            Spacer()
            timePeriodsSection
        }
        .padding(.vertical, Design.verticalPadding)
        .padding(.horizontal, Design.horizontalPadding)
        .background(backgroundColor)
        .cornerRadius(Design.cornerRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    // MARK: - Components
    
    private var dayNameSection: some View {
        Text(dayName)
            .font(isToday ? Design.todayFont : Design.dayFont)
            .foregroundColor(isToday ? .primary : .secondary)
            .frame(width: Design.dayNameWidth, alignment: .leading)
    }
    
    private var todayBadgeSection: some View {
        Group {
            if isToday {
                Text(Design.todayBadgeText)
                    .font(Design.todayBadgeFont)
                    .foregroundColor(Design.todayColor)
                    .padding(.horizontal, Design.todayBadgePadding)
                    .padding(.vertical, Design.todayBadgeVerticalPadding)
                    .background(Design.todayColor.opacity(Design.todayBadgeOpacity))
                    .cornerRadius(Design.todayBadgeCornerRadius)
            }
        }
    }
    
    private var timePeriodsSection: some View {
        VStack(alignment: .trailing, spacing: Design.timeSpacing) {
            ForEach(periods, id: \.startTime) { period in
                Text(formattedTimeRange(period))
                    .font(Design.timeFont)
                    .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        isToday ? Design.todayColor.opacity(Design.todayBackgroundOpacity) : Color.clear
    }
    
    private var accessibilityLabel: String {
        let timeText = periods.map { period in
            "\(formattedTimeRange(period))"
        }.joined(separator: ", ")
        
        let todayText = isToday ? "Today" : ""
        return "\(dayName) \(todayText) \(timeText)"
    }
    
    // MARK: - Helper Methods
    
    private func formattedTimeRange(_ period: BusinessHoursPeriod) -> String {
        let startTime = formatTime(period.startTime)
        let endTime = formatTime(period.endTime)
        return "\(startTime) - \(endTime)"
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

/**
 * BusinessHoursUnavailableView - Displays when business hours information is not available.
 *
 * ## Features
 * - **Consistent Styling**: Matches the main BusinessHoursView design
 * - **Clear Status**: Shows "Not Available" status clearly
 * - **Accessibility**: Full VoiceOver support with proper labels
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */
struct BusinessHoursUnavailableView: View {
    
    // MARK: - Design System
    
    enum Design {
        // Layout
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 2
        static let shadowOpacity: Double = 0.05
        static let borderWidth: CGFloat = 1
        static let statusCornerRadius: CGFloat = 6
        
        // Spacing
        static let verticalPadding: CGFloat = 12
        static let horizontalPadding: CGFloat = 16
        static let statusHorizontalPadding: CGFloat = 8
        static let statusVerticalPadding: CGFloat = 4
        
        // Typography
        static let titleFont = Font.subheadline.weight(.medium)
        static let statusFont = Font.caption.weight(.medium)
        
        // Icons
        static let clockIcon = "clock"
        static let iconSize: CGFloat = 16
        
        // Text
        static let titleText = "Business Hours"
        static let statusText = "Not Available"
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack {
            clockIcon
            titleText
            Spacer()
            statusBadge
        }
        .padding(.vertical, Design.verticalPadding)
        .padding(.horizontal, Design.horizontalPadding)
        .background(Color(.systemBackground))
        .cornerRadius(Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Design.cornerRadius)
                .stroke(Color(.systemGray5), lineWidth: Design.borderWidth)
        )
        .shadow(
            color: Color.black.opacity(Design.shadowOpacity),
            radius: Design.shadowRadius,
            x: 0,
            y: 1
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Design.titleText), \(Design.statusText)")
    }
    
    // MARK: - Components
    
    private var clockIcon: some View {
        Image(systemName: Design.clockIcon)
            .foregroundColor(.secondary)
            .font(.system(size: Design.iconSize, weight: .medium))
            .accessibilityHidden(true)
    }
    
    private var titleText: some View {
        Text(Design.titleText)
            .font(Design.titleFont)
            .foregroundColor(.primary)
    }
    
    private var statusBadge: some View {
        Text(Design.statusText)
            .font(Design.statusFont)
            .foregroundColor(.secondary)
            .padding(.horizontal, Design.statusHorizontalPadding)
            .padding(.vertical, Design.statusVerticalPadding)
            .background(Color(.systemGray6))
            .cornerRadius(Design.statusCornerRadius)
    }
}

// MARK: - Previews

#Preview("Business Hours - Open") {
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

#Preview("Business Hours - Closed") {
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
        isCurrentlyOpen: false
    )
    
    return BusinessHoursView(businessHoursInfo: sampleHours)
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Business Hours Unavailable") {
    BusinessHoursUnavailableView()
        .padding()
        .background(Color(.systemGroupedBackground))
} 