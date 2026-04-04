import SwiftUI
import Charts

// MARK: - Mock data for admin dashboard

private enum AdminData {
    struct BuildingUsage: Identifiable {
        let id = UUID()
        let name: String
        let sessions: Int
    }

    struct HourlyUsage: Identifiable {
        let id = UUID()
        let building: String
        let hour: Int
        let count: Int
    }

    struct DailyTrend: Identifiable {
        let id = UUID()
        let day: String
        let sessions: Int
    }

    struct MajorScore: Identifiable {
        let id = UUID()
        let major: String
        let avgScore: Int
    }

    struct YearHours: Identifiable {
        let id = UUID()
        let year: String
        let hours: Double
    }

    struct MajorBuilding: Identifiable {
        let id = UUID()
        let major: String
        let building: String
        let avgScore: Int
        let totalHours: Int
    }

    struct GenderStat: Identifiable {
        let id = UUID()
        let label: String
        let percent: Double
    }

    static let buildingUsage: [BuildingUsage] = [
        .init(name: "WALC", sessions: 892),
        .init(name: "HIKS", sessions: 654),
        .init(name: "LWSN", sessions: 543),
        .init(name: "PMU", sessions: 421),
        .init(name: "KNOY", sessions: 387),
        .init(name: "COREC", sessions: 312),
        .init(name: "HOVD", sessions: 278),
        .init(name: "STEW", sessions: 245),
        .init(name: "KRAN", sessions: 198),
        .init(name: "HAAS", sessions: 176),
    ]

    static let peakHours: [HourlyUsage] = {
        let buildings = ["WALC", "HIKS", "LWSN", "PMU", "KNOY", "COREC", "HOVD", "STEW"]
        let patterns: [String: [Int]] = [
            "WALC":  [2, 5, 12, 28, 45, 62, 58, 42, 35, 22, 15, 8, 5, 3, 2, 1, 0, 0],
            "HIKS":  [1, 3, 8, 15, 22, 30, 35, 45, 52, 48, 38, 25, 18, 10, 5, 2, 1, 0],
            "LWSN":  [2, 4, 10, 22, 35, 48, 42, 38, 30, 18, 12, 8, 5, 3, 2, 1, 0, 0],
            "PMU":   [3, 5, 8, 12, 18, 25, 22, 20, 15, 12, 8, 5, 3, 2, 1, 1, 0, 0],
            "KNOY":  [1, 3, 8, 18, 32, 42, 38, 28, 22, 15, 10, 6, 4, 2, 1, 0, 0, 0],
            "COREC": [5, 8, 12, 15, 10, 8, 12, 18, 25, 30, 22, 15, 10, 8, 5, 3, 2, 1],
            "HOVD":  [1, 2, 5, 10, 15, 20, 18, 15, 12, 8, 5, 3, 2, 1, 0, 0, 0, 0],
            "STEW":  [2, 3, 5, 8, 12, 18, 22, 20, 15, 10, 8, 5, 3, 2, 1, 0, 0, 0],
        ]
        var result: [HourlyUsage] = []
        for b in buildings {
            let counts = patterns[b] ?? []
            for (i, c) in counts.enumerated() {
                result.append(.init(building: b, hour: 6 + i, count: c))
            }
        }
        return result
    }()

    static let dailyTrend: [DailyTrend] = [
        .init(day: "Mon", sessions: 298),
        .init(day: "Tue", sessions: 342),
        .init(day: "Wed", sessions: 315),
        .init(day: "Thu", sessions: 378),
        .init(day: "Fri", sessions: 256),
        .init(day: "Sat", sessions: 189),
        .init(day: "Sun", sessions: 224),
    ]

    static let majorScores: [MajorScore] = [
        .init(major: "Computer Science", avgScore: 82),
        .init(major: "Science", avgScore: 80),
        .init(major: "Engineering", avgScore: 78),
        .init(major: "Liberal Arts", avgScore: 74),
        .init(major: "Business", avgScore: 71),
    ]

    static let yearHours: [YearHours] = [
        .init(year: "Freshman", hours: 8.2),
        .init(year: "Sophomore", hours: 10.1),
        .init(year: "Junior", hours: 12.4),
        .init(year: "Senior", hours: 9.8),
        .init(year: "Graduate", hours: 15.7),
    ]

    static let majorBuildings: [MajorBuilding] = [
        .init(major: "Computer Science", building: "LWSN", avgScore: 82, totalHours: 543),
        .init(major: "Engineering", building: "KNOY", avgScore: 78, totalHours: 412),
        .init(major: "Science", building: "HIKS", avgScore: 80, totalHours: 398),
        .init(major: "Business", building: "KRAN", avgScore: 71, totalHours: 287),
        .init(major: "Liberal Arts", building: "STEW", avgScore: 74, totalHours: 215),
    ]

    static let genderStats: [GenderStat] = [
        .init(label: "Female", percent: 44),
        .init(label: "Male", percent: 51),
        .init(label: "Other", percent: 5),
    ]
}

// MARK: - Admin Dashboard

struct AdminDashboardView: View {
    @AppStorage("isAdmin") private var isAdmin = false
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppColors.accent)
                    Text("FocusBet Admin")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                }

                Spacer()

                Text("Purdue University")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

                Button {
                    isAdmin = false
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 12))
                        Text("Log Out")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(AppColors.danger)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(AppColors.danger.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(AppColors.bgSecondary)
            .overlay(alignment: .bottom) { AppColors.border.frame(height: 1) }

            // Tab selector
            HStack(spacing: 0) {
                tabButton("Facilities", icon: "building.2.fill", index: 0)
                tabButton("Students", icon: "person.3.fill", index: 1)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            // Content
            ScrollView {
                if selectedTab == 0 {
                    facilitiesTab
                } else {
                    studentsTab
                }
            }
            .background(AppColors.bgPrimary)
        }
        .background(AppColors.bgPrimary)
        .toolbar(.hidden, for: .automatic)
    }

    private func tabButton(_ label: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 14, weight: selectedTab == index ? .semibold : .regular))
            }
            .foregroundStyle(selectedTab == index ? AppColors.accent : AppColors.textMuted)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(selectedTab == index ? AppColors.accent.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Facilities Tab

    private var facilitiesTab: some View {
        VStack(spacing: 20) {
            // Key metrics
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                metricCard("Total Active Users", "1,247", "person.2.fill")
                metricCard("Sessions Today", "342", "clock.fill")
                metricCard("Avg Session Duration", "2.1 hrs", "timer")
                metricCard("Campus Utilization", "67%", "building.fill")
            }

            // Building usage chart
            adminCard("Building Usage This Week") {
                Chart(AdminData.buildingUsage) { item in
                    BarMark(
                        x: .value("Sessions", item.sessions),
                        y: .value("Building", item.name)
                    )
                    .foregroundStyle(AppColors.accent)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(AppColors.border)
                        AxisValueLabel()
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .frame(height: 300)
            }

            // Peak hours heatmap
            adminCard("Peak Hours Heatmap") {
                peakHoursGrid
            }

            // Daily trend
            adminCard("Daily Usage Trend (Last 7 Days)") {
                Chart(AdminData.dailyTrend) { item in
                    LineMark(
                        x: .value("Day", item.day),
                        y: .value("Sessions", item.sessions)
                    )
                    .foregroundStyle(AppColors.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("Day", item.day),
                        y: .value("Sessions", item.sessions)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [AppColors.accent.opacity(0.3), AppColors.accent.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    PointMark(
                        x: .value("Day", item.day),
                        y: .value("Sessions", item.sessions)
                    )
                    .foregroundStyle(AppColors.accent)
                    .symbolSize(30)
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(AppColors.border)
                        AxisValueLabel()
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .frame(height: 200)
            }
        }
        .padding(24)
    }

    // MARK: - Students Tab

    private var studentsTab: some View {
        VStack(spacing: 20) {
            // Key metrics
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                metricCard("Total Registered", "1,247", "person.crop.circle.fill")
                metricCard("Avg Focus Score", "76", "brain.head.profile")
                metricCard("Weekly Active Rate", "68%", "chart.line.uptrend.xyaxis")
            }

            // Focus score by major
            adminCard("Focus Score by Major") {
                Chart(AdminData.majorScores) { item in
                    BarMark(
                        x: .value("Score", item.avgScore),
                        y: .value("Major", item.major)
                    )
                    .foregroundStyle(AppColors.accent)
                    .cornerRadius(4)
                    .annotation(position: .trailing, spacing: 4) {
                        Text("\(item.avgScore)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .chartXScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(AppColors.border)
                        AxisValueLabel()
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .frame(height: 200)
            }

            // Study hours by year
            adminCard("Study Hours by Year (Weekly Avg)") {
                Chart(AdminData.yearHours) { item in
                    BarMark(
                        x: .value("Year", item.year),
                        y: .value("Hours", item.hours)
                    )
                    .foregroundStyle(AppColors.accent.gradient)
                    .cornerRadius(6)
                    .annotation(position: .top, spacing: 4) {
                        Text("\(item.hours, specifier: "%.1f")h")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(AppColors.border)
                        AxisValueLabel()
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .frame(height: 220)
            }

            // Preferred buildings by major
            adminCard("Preferred Buildings by Major") {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Major").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Building").frame(width: 80)
                        Text("Avg Score").frame(width: 80)
                        Text("Total Hours").frame(width: 90)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                    AppColors.border.frame(height: 1)

                    ForEach(AdminData.majorBuildings) { row in
                        HStack {
                            Text(row.major)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(AppColors.textPrimary)
                            Text(row.building)
                                .frame(width: 80)
                                .foregroundStyle(AppColors.accent)
                                .fontWeight(.semibold)
                            Text("\(row.avgScore)")
                                .frame(width: 80)
                                .foregroundStyle(AppColors.textSecondary)
                            Text("\(row.totalHours)hrs")
                                .frame(width: 90)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .font(.system(size: 13))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)

                        if row.id != AdminData.majorBuildings.last?.id {
                            AppColors.border.opacity(0.5).frame(height: 1).padding(.horizontal, 12)
                        }
                    }
                }
            }

            // Gender distribution
            adminCard("Gender Distribution") {
                HStack(spacing: 32) {
                    Chart(AdminData.genderStats) { item in
                        SectorMark(
                            angle: .value("Percent", item.percent),
                            innerRadius: .ratio(0.6),
                            outerRadius: .ratio(1.0)
                        )
                        .foregroundStyle(by: .value("Gender", item.label))
                    }
                    .chartForegroundStyleScale([
                        "Female": AppColors.userColors[4],
                        "Male": AppColors.userColors[3],
                        "Other": AppColors.textMuted,
                    ])
                    .chartLegend(.hidden)
                    .frame(width: 160, height: 160)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(AdminData.genderStats) { stat in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(genderColor(stat.label))
                                    .frame(width: 10, height: 10)
                                Text(stat.label)
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppColors.textPrimary)
                                Spacer()
                                Text("\(Int(stat.percent))%")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }
                    .frame(width: 160)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding(24)
    }

    private func genderColor(_ label: String) -> Color {
        switch label {
        case "Female": return AppColors.userColors[4]
        case "Male": return AppColors.userColors[3]
        default: return AppColors.textMuted
        }
    }

    // MARK: - Reusable Components

    private func metricCard(_ label: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.accent)
                Spacer()
            }
            HStack {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.accent)
                Spacer()
            }
            HStack {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
            }
        }
        .padding(16)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
    }

    private func adminCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
            content()
        }
        .padding(20)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
    }

    // MARK: - Peak Hours Grid

    private var peakHoursGrid: some View {
        let buildings = ["WALC", "HIKS", "LWSN", "PMU", "KNOY", "COREC", "HOVD", "STEW"]
        let hours = Array(6...23)
        let maxCount = AdminData.peakHours.map(\.count).max() ?? 1

        return VStack(spacing: 2) {
            // Hour labels
            HStack(spacing: 2) {
                Text("")
                    .frame(width: 50)
                ForEach(hours, id: \.self) { h in
                    Text(h <= 12 ? "\(h)a" : "\(h - 12)p")
                        .font(.system(size: 8))
                        .foregroundStyle(AppColors.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(buildings, id: \.self) { building in
                HStack(spacing: 2) {
                    Text(building)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 50, alignment: .trailing)

                    ForEach(hours, id: \.self) { hour in
                        let count = AdminData.peakHours.first {
                            $0.building == building && $0.hour == hour
                        }?.count ?? 0
                        let intensity = Double(count) / Double(maxCount)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatColor(intensity))
                            .frame(maxWidth: .infinity)
                            .frame(height: 20)
                    }
                }
            }

            // Legend
            HStack(spacing: 4) {
                Spacer()
                Text("Low")
                    .font(.system(size: 9))
                    .foregroundStyle(AppColors.textMuted)
                ForEach([0.1, 0.3, 0.5, 0.7, 0.9], id: \.self) { v in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatColor(v))
                        .frame(width: 14, height: 10)
                }
                Text("High")
                    .font(.system(size: 9))
                    .foregroundStyle(AppColors.textMuted)
            }
            .padding(.top, 4)
        }
    }

    private func heatColor(_ intensity: Double) -> Color {
        if intensity < 0.05 { return AppColors.bgTertiary }
        return AppColors.accent.opacity(0.15 + intensity * 0.85)
    }
}
