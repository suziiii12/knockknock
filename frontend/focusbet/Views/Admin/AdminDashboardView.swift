import SwiftUI
import Charts

// MARK: - Admin Dashboard

struct AdminDashboardView: View {
    @AppStorage("isAdmin") private var isAdmin = false
    @State private var selectedTab = 0
    @State private var dateRange = "This Week"

    private let dateRanges = ["This Week", "This Month", "All Time"]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: 20) {
                    overviewCards
                    tabSelector
                    tabContent
                    ferpaNotice
                }
                .padding(24)
            }
            .background(AppColors.bgPrimary)
        }
        .background(AppColors.bgPrimary)
        .toolbar(.hidden, for: .automatic)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.accent)
                Text("FocusBet Admin")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
            }

            Spacer()

            Text("Purdue University")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)

            Spacer()

            HStack(spacing: 8) {
                ForEach(dateRanges, id: \.self) { range in
                    Button {
                        dateRange = range
                    } label: {
                        Text(range)
                            .font(.system(size: 11, weight: dateRange == range ? .semibold : .regular))
                            .foregroundStyle(dateRange == range ? .white : AppColors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(dateRange == range ? AppColors.accent : AppColors.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    print("Export PDF")
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc").font(.system(size: 11))
                        Text("Export PDF").font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppColors.accent, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    isAdmin = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 11))
                        Text("Log Out").font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(AppColors.danger)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColors.danger.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(AppColors.bgSecondary)
        .overlay(alignment: .bottom) { AppColors.border.frame(height: 1) }
    }

    // MARK: - Overview Cards

    private var overviewCards: some View {
        let metrics: [(String, String, String, Bool?)] = [
            ("847", "Sessions this week", "\u{2191} 12%", true),
            ("214", "Active users", "+28 new", true),
            ("74.2", "Avg focus score", "\u{2191} 3.1 pts", true),
            ("58m", "Avg session length", "\u{2192} unchanged", nil),
        ]

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
            ForEach(metrics, id: \.0) { value, label, change, positive in
                VStack(alignment: .leading, spacing: 6) {
                    Text(value)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.textSecondary)
                    Text(change)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(positive == true ? AppColors.accentLight : AppColors.textMuted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
                .shadow(color: AppColors.cardShadow, radius: 6, y: 2)
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabBtn("Study Spaces", 0)
            tabBtn("Program Effectiveness", 1)
            tabBtn("Retention Signals", 2)
            Spacer()
        }
    }

    private func tabBtn(_ label: String, _ index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = index }
        } label: {
            VStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 13, weight: selectedTab == index ? .semibold : .regular))
                    .foregroundStyle(selectedTab == index ? AppColors.accent : AppColors.textMuted)
                Rectangle()
                    .fill(selectedTab == index ? AppColors.accent : Color.clear)
                    .frame(height: 2)
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: studySpacesTab
        case 1: programEffectivenessTab
        default: retentionSignalsTab
        }
    }

    // MARK: - Tab 1: Study Spaces

    private var studySpacesTab: some View {
        let buildingFocus: [(String, Int)] = [
            ("HSSE 3rd Floor", 82), ("WALC Basement", 79), ("Hicks 2nd Floor", 76),
            ("WALC 1st Floor", 71), ("PMU Study Room", 68), ("Krach Atrium", 64),
            ("WALC Main Floor", 58), ("Hicks Main", 55),
        ]
        let hourlyFocus: [(Int, Int)] = [
            (8, 62), (9, 68), (10, 74), (11, 78), (12, 65), (13, 70),
            (14, 76), (15, 80), (16, 78), (17, 72), (18, 68), (19, 74),
            (20, 79), (21, 82), (22, 78), (23, 71),
        ]
        let occupancy: [(String, String, Int, String)] = [
            ("HSSE 3rd Floor", "45%", 82, "High quality"),
            ("WALC Basement", "72%", 79, "High quality"),
            ("Hicks 2nd Floor", "58%", 76, "High quality"),
            ("WALC Main Floor", "95%", 58, "Overcrowded"),
            ("Krach Atrium", "82%", 64, "Needs attention"),
        ]

        return VStack(alignment: .leading, spacing: 16) {
            Text("For: Purdue Libraries — Space Planning & Occupancy Quality")
                .font(.system(size: 11)).italic()
                .foregroundStyle(AppColors.textMuted)

            HStack(alignment: .top, spacing: 16) {
                card("Avg Focus Score by Building") {
                    Chart(buildingFocus, id: \.0) { name, score in
                        BarMark(x: .value("Score", score), y: .value("Building", name))
                            .foregroundStyle(score >= 75 ? AppColors.accentLight : (score >= 60 ? AppColors.warning : AppColors.danger))
                            .cornerRadius(4)
                    }
                    .chartXScale(domain: 0...100)
                    .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(AppColors.textMuted) } }
                    .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(AppColors.textSecondary) } }
                    .frame(height: 240)
                }

                card("Focus by Time of Day") {
                    Chart(hourlyFocus, id: \.0) { hour, score in
                        BarMark(
                            x: .value("Hour", hourLabel(hour)),
                            y: .value("Score", score)
                        )
                        .foregroundStyle(AppColors.accentLight.gradient)
                        .cornerRadius(3)
                    }
                    .chartYScale(domain: 40...90)
                    .chartYAxis { AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(AppColors.border)
                        AxisValueLabel().foregroundStyle(AppColors.textMuted)
                    } }
                    .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(AppColors.textMuted) } }
                    .frame(height: 240)
                }
            }

            card("Occupancy vs Focus") {
                tableView(
                    headers: ["Space", "Avg Occupancy", "Avg Focus", "Signal"],
                    rows: occupancy.map { name, occ, focus, signal in
                        [name, occ, "\(focus)", signal]
                    },
                    signalColumn: 3
                )
            }
        }
    }

    // MARK: - Tab 2: Program Effectiveness

    private var programEffectivenessTab: some View {
        let programs: [(String, Double, Double)] = [
            ("Peer Success Coaching", 61.2, 72.8),
            ("Supplemental Instruction", 65.4, 74.1),
            ("Accountability Groups", 58.9, 67.3),
            ("Study Skills Consultations", 60.1, 63.8),
        ]
        let cohorts: [(String, Double)] = [
            ("PSC Participants", 4.8), ("SI Participants", 4.2),
            ("Non-participants", 2.9), ("Academic Notice", 1.7),
        ]
        let contentTypes: [(String, Int)] = [
            ("Problem Sets", 78), ("Writing", 74), ("Reading", 71),
            ("Video Lectures", 65), ("Flashcards", 62),
        ]

        return VStack(alignment: .leading, spacing: 16) {
            Text("For: Academic Success Center — Coaching & Program Impact")
                .font(.system(size: 11)).italic()
                .foregroundStyle(AppColors.textMuted)

            card("Before vs After Focus by Program") {
                let flat: [(String, String, Double)] = programs.flatMap { name, before, after in
                    [(name, "Before", before), (name, "After", after)]
                }
                Chart(flat, id: \.0) { name, type, score in
                    BarMark(x: .value("Score", score), y: .value("Program", name))
                        .foregroundStyle(type == "After" ? AppColors.accentLight : AppColors.textMuted)
                        .cornerRadius(4)
                        .position(by: .value("Type", type))
                }
                .chartXScale(domain: 0...100)
                .chartForegroundStyleScale(["Before": AppColors.textMuted, "After": AppColors.accentLight])
                .chartXAxis { AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(AppColors.border)
                    AxisValueLabel().foregroundStyle(AppColors.textMuted)
                } }
                .chartYAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 11)).foregroundStyle(AppColors.textSecondary) } }
                .frame(height: 200)
            }

            HStack(alignment: .top, spacing: 16) {
                card("Study Days per Week by Cohort") {
                    Chart(cohorts, id: \.0) { name, days in
                        BarMark(x: .value("Cohort", name), y: .value("Days", days))
                            .foregroundStyle(days >= 4 ? AppColors.accentLight : (days >= 3 ? AppColors.warning : AppColors.danger))
                            .cornerRadius(4)
                            .annotation(position: .top, spacing: 2) {
                                Text("\(days, specifier: "%.1f")")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                    }
                    .chartYScale(domain: 0...6)
                    .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(AppColors.textMuted) } }
                    .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(AppColors.textMuted) } }
                    .frame(height: 200)
                }

                card("Focus Score by Content Type") {
                    Chart(contentTypes, id: \.0) { name, score in
                        BarMark(x: .value("Score", score), y: .value("Type", name))
                            .foregroundStyle(AppColors.accentLight)
                            .cornerRadius(4)
                    }
                    .chartXScale(domain: 0...100)
                    .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(AppColors.textMuted) } }
                    .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(AppColors.textSecondary) } }
                    .frame(height: 200)
                }
            }
        }
    }

    // MARK: - Tab 3: Retention Signals

    private var retentionSignalsTab: some View {
        let semesterTrend: [(Int, Int)] = [
            (1, 72), (2, 74), (3, 76), (4, 78), (5, 77), (6, 75),
            (7, 65), (8, 62), (9, 70), (10, 73), (11, 76), (12, 78),
            (13, 74), (14, 71), (15, 68), (16, 64),
        ]
        let yearData: [(String, Int)] = [
            ("Freshman", 68), ("Sophomore", 72), ("Junior", 76), ("Senior", 74), ("Graduate", 80),
        ]
        let collegeData: [(String, Int)] = [
            ("Engineering", 76), ("Science", 74), ("Management", 71), ("Liberal Arts", 69),
        ]
        let courseData: [(String, Int, Double, String, String)] = [
            ("MA 153", 412, 58.2, "187 (45%)", "+9.4 pts"),
            ("CHM 115", 389, 61.4, "143 (37%)", "+7.1 pts"),
            ("PHYS 172", 521, 55.8, "198 (38%)", "+4.2 pts"),
            ("BIOL 110", 298, 63.1, "89 (30%)", "+3.8 pts"),
        ]

        return VStack(alignment: .leading, spacing: 16) {
            Text("For: VP Student Success — Early Alert & Semester Trends")
                .font(.system(size: 11)).italic()
                .foregroundStyle(AppColors.textMuted)

            card("Campus Focus Trend — Semester Arc") {
                Chart(semesterTrend, id: \.0) { week, score in
                    LineMark(x: .value("Week", week), y: .value("Score", score))
                        .foregroundStyle(AppColors.accentLight)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    AreaMark(x: .value("Week", week), y: .value("Score", score))
                        .foregroundStyle(
                            .linearGradient(colors: [AppColors.accentLight.opacity(0.2), .clear],
                                            startPoint: .top, endPoint: .bottom)
                        )
                    PointMark(x: .value("Week", week), y: .value("Score", score))
                        .foregroundStyle(score <= 65 ? AppColors.danger : AppColors.accentLight)
                        .symbolSize(score <= 65 ? 40 : 20)
                }
                .chartYScale(domain: 50...85)
                .chartXAxis { AxisMarks(values: [1, 4, 7, 8, 12, 16]) { v in
                    AxisValueLabel {
                        if let w = v.as(Int.self) { Text("Wk \(w)").font(.system(size: 9)).foregroundStyle(AppColors.textMuted) }
                    }
                } }
                .chartYAxis { AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(AppColors.border)
                    AxisValueLabel().foregroundStyle(AppColors.textMuted)
                } }
                .frame(height: 180)

                HStack(spacing: 4) {
                    Circle().fill(AppColors.danger).frame(width: 6, height: 6)
                    Text("Midterm dip (Weeks 7-8)").font(.system(size: 9)).foregroundStyle(AppColors.textMuted)
                }
            }

            // Alert cards
            HStack(spacing: 14) {
                alertCard("23 students", "3+ week decline, not on BoilerConnect", .red)
                alertCard("41 students", "2-week decline, partially flagged", .orange)
                alertCard("67 students", "Showed decline but recovered", .green)
            }
            Text("All counts are aggregate only. No individual student data is displayed.")
                .font(.system(size: 9)).italic()
                .foregroundStyle(AppColors.textMuted)

            HStack(alignment: .top, spacing: 16) {
                card("Focus by Student Year") {
                    Chart(yearData, id: \.0) { year, score in
                        BarMark(x: .value("Year", year), y: .value("Score", score))
                            .foregroundStyle(AppColors.accentLight.gradient)
                            .cornerRadius(4)
                    }
                    .chartYScale(domain: 50...90)
                    .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(AppColors.textMuted) } }
                    .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(AppColors.textMuted) } }
                    .frame(height: 180)
                }
                card("Focus by College") {
                    Chart(collegeData, id: \.0) { college, score in
                        BarMark(x: .value("College", college), y: .value("Score", score))
                            .foregroundStyle(AppColors.accentLight.gradient)
                            .cornerRadius(4)
                    }
                    .chartYScale(domain: 50...90)
                    .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(AppColors.textMuted) } }
                    .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(AppColors.textMuted) } }
                    .frame(height: 180)
                }
            }

            card("DFW Course Tracking") {
                VStack(spacing: 0) {
                    HStack {
                        Text("Course").frame(width: 80, alignment: .leading)
                        Text("Enrollment").frame(width: 80)
                        Text("Avg Focus").frame(width: 80)
                        Text("Incentive Participants").frame(maxWidth: .infinity)
                        Text("Focus Lift").frame(width: 80)
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.textMuted)
                    .padding(.horizontal, 12).padding(.bottom, 6)

                    AppColors.border.frame(height: 1)

                    ForEach(courseData, id: \.0) { course, enroll, focus, participants, lift in
                        HStack {
                            Text(course).fontWeight(.semibold).frame(width: 80, alignment: .leading)
                            Text("\(enroll)").frame(width: 80)
                            Text(String(format: "%.1f", focus))
                                .foregroundStyle(focus < 60 ? AppColors.danger : AppColors.textSecondary)
                                .frame(width: 80)
                            Text(participants).frame(maxWidth: .infinity)
                            Text(lift)
                                .foregroundStyle(AppColors.accentLight)
                                .fontWeight(.semibold)
                                .frame(width: 80)
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(courseData.firstIndex(where: { $0.0 == course })! % 2 == 1 ? AppColors.bgPrimary : Color.clear)
                    }
                }
            }
        }
    }

    // MARK: - Reusable Components

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .shadow(color: AppColors.cardShadow, radius: 6, y: 2)
    }

    private func alertCard(_ count: String, _ desc: String, _ level: AlertLevel) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(level.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(count)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(level.label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(level.color)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(level.color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: AppColors.cardShadow, radius: 4, y: 1)
    }

    private enum AlertLevel {
        case red, orange, green
        var color: Color {
            switch self {
            case .red: return AppColors.danger
            case .orange: return AppColors.warning
            case .green: return AppColors.accentLight
            }
        }
        var label: String {
            switch self {
            case .red: return "High Risk"
            case .orange: return "Monitor"
            case .green: return "Resolved"
            }
        }
    }

    private func tableView(headers: [String], rows: [[String]], signalColumn: Int?) -> some View {
        VStack(spacing: 0) {
            HStack {
                ForEach(headers.indices, id: \.self) { i in
                    Text(headers[i])
                        .frame(maxWidth: .infinity, alignment: i == 0 ? .leading : .center)
                }
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(AppColors.textMuted)
            .padding(.horizontal, 12).padding(.bottom, 6)

            AppColors.border.frame(height: 1)

            ForEach(rows.indices, id: \.self) { rowIdx in
                HStack {
                    ForEach(rows[rowIdx].indices, id: \.self) { colIdx in
                        if colIdx == signalColumn {
                            Text(rows[rowIdx][colIdx])
                                .foregroundStyle(signalColor(rows[rowIdx][colIdx]))
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Text(rows[rowIdx][colIdx])
                                .foregroundStyle(colIdx == 0 ? AppColors.textPrimary : AppColors.textSecondary)
                                .fontWeight(colIdx == 0 ? .medium : .regular)
                                .frame(maxWidth: .infinity, alignment: colIdx == 0 ? .leading : .center)
                        }
                    }
                }
                .font(.system(size: 11))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(rowIdx % 2 == 1 ? AppColors.bgPrimary : Color.clear)
            }
        }
    }

    private func signalColor(_ signal: String) -> Color {
        if signal.contains("High quality") { return AppColors.accentLight }
        if signal.contains("Overcrowded") { return AppColors.warning }
        return AppColors.danger
    }

    private func hourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }

    private var ferpaNotice: some View {
        Text("All data is anonymized and aggregate. Minimum cohort size of 10. FERPA compliant.")
            .font(.system(size: 9)).italic()
            .foregroundStyle(AppColors.textMuted)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
    }
}
