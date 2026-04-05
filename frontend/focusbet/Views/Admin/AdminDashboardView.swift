import SwiftUI
import Charts

// MARK: - Admin ViewModel

@Observable
@MainActor
private class AdminViewModel {

    // MARK: - Chart data (same tuple types the view uses)
    var buildingFocus:  [(String, Int)]  = []   // (abbreviation, avgScore)
    var hourlyFocus:    [(Int, Int)]     = []   // (hour 0-23, avgScore)
    var dailyUsage:     [(String, Int)]  = []   // (day name, sessionCount)
    var semesterTrend:  [(Int, Int)]     = []   // (weekNum, avgScore)
    var yearFocus:      [(String, Int)]  = []   // (year label, avgScore)
    var collegeFocus:   [(String, Int)]  = []   // (major, avgScore)

    // Overview KPIs
    var totalSessions:       Int    = 0
    var activeUsers:         Int    = 0
    var avgFocusScore:       Double = 0
    var avgDurationMinutes:  Double = 0

    var isLoading = true

    private let base = "http://35.206.125.242:8080"

    // MARK: - Load

    func loadAllData() async {
        isLoading = true
        async let ov = fetchOverview()
        async let bf = fetchBuildingFocus()
        async let hf = fetchHourlyFocus()
        async let du = fetchDailyUsage()
        async let yf = fetchYearFocus()
        async let cf = fetchCollegeFocus()
        async let st = fetchSemesterTrend()

        let (o, b, h, d, y, c, s) = await (ov, bf, hf, du, yf, cf, st)
        totalSessions       = o.0
        activeUsers         = o.1
        avgFocusScore       = o.2
        avgDurationMinutes  = o.3
        buildingFocus       = b
        hourlyFocus         = h
        dailyUsage          = d
        yearFocus           = y
        collegeFocus        = c
        semesterTrend       = s
        isLoading = false
    }

    // MARK: - Fetch helpers

    private func get(_ path: String) async throws -> Any {
        guard let url = URL(string: "\(base)\(path)") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data)
        guard let dict = json as? [String: Any], let d = dict["data"] else { throw URLError(.cannotParseResponse) }
        return d
    }

    private func fetchOverview() async -> (Int, Int, Double, Double) {
        let mock = (847, 214, 74.2, 58.0)
        do {
            guard let d = try await get("/admin/overview") as? [String: Any] else { return mock }
            return (
                d["total_sessions"]        as? Int    ?? 0,
                d["active_users"]          as? Int    ?? 0,
                d["avg_focus_score"]       as? Double ?? 0,
                d["avg_duration_minutes"]  as? Double ?? 0
            )
        } catch { return mock }
    }

    private func fetchBuildingFocus() async -> [(String, Int)] {
        let mock: [(String, Int)] = [
            ("WALC",79),("HIKS",76),("LWSN",74),("KNOY",72),
            ("PMU",68),("KRCH",64),("HOVD",62),("STEW",60),("COREC",58),
        ]
        do {
            guard let arr = try await get("/admin/building-focus") as? [[String: Any]] else { return mock }
            let result = arr.compactMap { d -> (String, Int)? in
                guard let abbr = d["abbreviation"] as? String,
                      let score = d["avg_score"] as? Double else { return nil }
                return (abbr, Int(score))
            }
            return result.isEmpty ? mock : result
        } catch { return mock }
    }

    private func fetchHourlyFocus() async -> [(Int, Int)] {
        let mock: [(Int, Int)] = [
            (8,62),(9,68),(10,74),(11,78),(12,65),(13,70),
            (14,76),(15,80),(16,78),(17,72),(18,68),(19,74),
            (20,79),(21,82),(22,78),(23,71),
        ]
        do {
            guard let arr = try await get("/admin/hourly-focus") as? [[String: Any]] else { return mock }
            let result = arr.compactMap { d -> (Int, Int)? in
                guard let h = d["hour"] as? Int, let s = d["avg_score"] as? Double else { return nil }
                return (h, Int(s))
            }
            return result.isEmpty ? mock : result
        } catch { return mock }
    }

    private func fetchDailyUsage() async -> [(String, Int)] {
        let mock: [(String, Int)] = [
            ("Mon",156),("Tue",142),("Wed",168),
            ("Thu",151),("Fri",98),("Sat",72),("Sun",60),
        ]
        do {
            guard let arr = try await get("/admin/daily-usage") as? [[String: Any]] else { return mock }
            let result = arr.compactMap { d -> (String, Int)? in
                guard let day = d["day"] as? String, let count = d["count"] as? Int else { return nil }
                return (day, count)
            }
            return result.isEmpty ? mock : result
        } catch { return mock }
    }

    private func fetchYearFocus() async -> [(String, Int)] {
        let mock: [(String, Int)] = [
            ("Graduate",80),("Junior",76),("Senior",74),("Sophomore",72),("Freshman",68),
        ]
        do {
            guard let arr = try await get("/admin/year-focus") as? [[String: Any]] else { return mock }
            let result = arr.compactMap { d -> (String, Int)? in
                guard let y = d["year"] as? String, let s = d["avg_score"] as? Double else { return nil }
                return (y, Int(s))
            }
            return result.isEmpty ? mock : result
        } catch { return mock }
    }

    private func fetchCollegeFocus() async -> [(String, Int)] {
        let mock: [(String, Int)] = [
            ("Engineering",76),("Science",74),("Management",71),("Liberal Arts",69),
        ]
        do {
            guard let arr = try await get("/admin/college-focus") as? [[String: Any]] else { return mock }
            let result = arr.compactMap { d -> (String, Int)? in
                guard let m = d["major"] as? String, let s = d["avg_score"] as? Double else { return nil }
                return (m, Int(s))
            }
            return result.isEmpty ? mock : result
        } catch { return mock }
    }

    private func fetchSemesterTrend() async -> [(Int, Int)] {
        let mock: [(Int, Int)] = [
            (1,72),(2,74),(3,76),(4,78),(5,77),(6,75),
            (7,65),(8,62),(9,70),(10,73),(11,76),(12,78),
            (13,74),(14,71),(15,68),(16,64),
        ]
        do {
            guard let arr = try await get("/admin/semester-trend") as? [[String: Any]] else { return mock }
            let result = arr.compactMap { d -> (Int, Int)? in
                guard let w = d["week"] as? Int, let s = d["avg_score"] as? Double else { return nil }
                return (w, Int(s))
            }
            return result.isEmpty ? mock : result
        } catch { return mock }
    }
}

// MARK: - Admin Dashboard

struct AdminDashboardView: View {
    @AppStorage("isAdmin") private var isAdmin = false
    @State private var vm = AdminViewModel()
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
        .task { await vm.loadAllData() }
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

                Button { print("Export PDF") } label: {
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

                Button { isAdmin = false } label: {
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
        let sessions  = vm.isLoading ? "—" : "\(vm.totalSessions)"
        let users     = vm.isLoading ? "—" : "\(vm.activeUsers)"
        let focus     = vm.isLoading ? "—" : String(format: "%.1f", vm.avgFocusScore)
        let duration  = vm.isLoading ? "—" : "\(Int(vm.avgDurationMinutes))m"

        let metrics: [(String, String, String, Bool?)] = [
            (sessions,  "Sessions this week",  vm.isLoading ? "..." : "live data",  true),
            (users,     "Active users",         vm.isLoading ? "..." : "live data",  true),
            (focus,     "Avg focus score",      vm.isLoading ? "..." : "live data",  true),
            (duration,  "Avg session length",   vm.isLoading ? "..." : "live data",  nil),
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
                        .foregroundStyle(positive == true ? AppColors.accent : AppColors.textMuted)
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
            tabBtn("Retention Signals", 1)
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
        default: retentionSignalsTab
        }
    }

    // MARK: - Tab 1: Study Spaces

    private var studySpacesTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("For: Purdue Libraries — Space Planning & Occupancy Quality")
                .font(.system(size: 11)).italic()
                .foregroundStyle(AppColors.textMuted)

            HStack(alignment: .top, spacing: 16) {
                card("Avg Focus Score by Building") {
                    Chart(vm.buildingFocus, id: \.0) { name, score in
                        BarMark(x: .value("Score", score), y: .value("Building", name))
                            .foregroundStyle(AppColors.accent)
                            .cornerRadius(4)
                    }
                    .chartXScale(domain: 0...100)
                    .chartXAxis { AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(AppColors.border)
                        AxisValueLabel().foregroundStyle(AppColors.textMuted)
                    } }
                    .chartYAxis { AxisMarks { _ in
                        AxisValueLabel().font(.system(size: 11)).foregroundStyle(AppColors.textSecondary)
                    } }
                    .frame(height: 260)
                }

                card("Focus by Time of Day") {
                    Chart(vm.hourlyFocus, id: \.0) { hour, score in
                        BarMark(
                            x: .value("Hour", hourLabel(hour)),
                            y: .value("Score", score)
                        )
                        .foregroundStyle(AppColors.accent)
                        .cornerRadius(3)
                    }
                    .chartYScale(domain: 40...90)
                    .chartYAxis { AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(AppColors.border)
                        AxisValueLabel().foregroundStyle(AppColors.textMuted)
                    } }
                    .chartXAxis { AxisMarks { _ in
                        AxisValueLabel().foregroundStyle(AppColors.textMuted)
                    } }
                    .frame(height: 260)
                }
            }

            card("Usage by Day of Week") {
                Chart(vm.dailyUsage, id: \.0) { day, sessions in
                    BarMark(
                        x: .value("Day", day),
                        y: .value("Sessions", sessions)
                    )
                    .foregroundStyle(AppColors.accent)
                    .cornerRadius(4)
                    .annotation(position: .top, spacing: 3) {
                        Text("\(sessions)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
                .chartYAxis { AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(AppColors.border)
                    AxisValueLabel().foregroundStyle(AppColors.textMuted)
                } }
                .chartXAxis { AxisMarks { _ in
                    AxisValueLabel().font(.system(size: 12)).foregroundStyle(AppColors.textSecondary)
                } }
                .frame(height: 200)
            }
        }
    }

    // MARK: - Tab 2: Retention Signals

    private var retentionSignalsTab: some View {
        // Correlation and major detail remain mock (require richer data model)
        let majorDetailData: [(String, Double, Int)] = [
            ("Computer Science", 14.2, 82), ("Engineering", 12.8, 78),
            ("Science", 11.5, 74), ("Liberal Arts", 9.1, 69), ("Business", 8.4, 71),
        ]
        let correlationData: [(hours: Double, focus: Double)] = [
            (2,45),(3,52),(4,58),(5,65),(6,68),(7,72),(8,74),(9,76),(10,80),
            (11,82),(12,83),(13,84),(14,82),(15,80),(16,78),(17,75),(18,72),
            (19,68),(20,65),(22,60),(24,55),
        ]

        return VStack(alignment: .leading, spacing: 16) {
            Text("For: VP Student Success — Early Alert & Semester Trends")
                .font(.system(size: 11)).italic()
                .foregroundStyle(AppColors.textMuted)

            card("Campus Focus Trend — Semester Arc") {
                Chart(vm.semesterTrend, id: \.0) { week, score in
                    LineMark(x: .value("Week", week), y: .value("Score", score))
                        .foregroundStyle(AppColors.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    AreaMark(x: .value("Week", week), y: .value("Score", score))
                        .foregroundStyle(
                            .linearGradient(colors: [AppColors.accent.opacity(0.15), .clear],
                                            startPoint: .top, endPoint: .bottom)
                        )
                    PointMark(x: .value("Week", week), y: .value("Score", score))
                        .foregroundStyle(score <= 65 ? AppColors.danger : AppColors.accent)
                        .symbolSize(score <= 65 ? 40 : 20)
                }
                .chartYScale(domain: 50...85)
                .chartXAxis { AxisMarks(values: [1, 4, 7, 8, 12, 16]) { v in
                    AxisValueLabel {
                        if let w = v.as(Int.self) {
                            Text("Wk \(w)").font(.system(size: 9)).foregroundStyle(AppColors.textMuted)
                        }
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
                    Chart(vm.yearFocus, id: \.0) { year, score in
                        BarMark(x: .value("Score", score), y: .value("Year", year))
                            .foregroundStyle(AppColors.accent)
                            .cornerRadius(4)
                    }
                    .chartXScale(domain: 0...100)
                    .chartXAxis { AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(AppColors.border)
                        AxisValueLabel().foregroundStyle(AppColors.textMuted)
                    } }
                    .chartYAxis { AxisMarks { _ in
                        AxisValueLabel().font(.system(size: 11)).foregroundStyle(AppColors.textSecondary)
                    } }
                    .frame(height: 160)
                }

                card("Focus by College") {
                    Chart(vm.collegeFocus, id: \.0) { college, score in
                        BarMark(x: .value("Score", score), y: .value("College", college))
                            .foregroundStyle(AppColors.accent)
                            .cornerRadius(4)
                    }
                    .chartXScale(domain: 0...100)
                    .chartXAxis { AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(AppColors.border)
                        AxisValueLabel().foregroundStyle(AppColors.textMuted)
                    } }
                    .chartYAxis { AxisMarks { _ in
                        AxisValueLabel().font(.system(size: 11)).foregroundStyle(AppColors.textSecondary)
                    } }
                    .frame(height: 140)
                }
            }

            card("Avg Focus Score & Study Hours by Major") {
                let flat: [(String, String, Double)] = majorDetailData.flatMap { major, hours, focus in
                    [(major, "Study Hours/wk", hours), (major, "Focus Score", Double(focus))]
                }
                Chart(flat, id: \.0) { major, metric, value in
                    BarMark(x: .value("Value", value), y: .value("Major", major))
                        .foregroundStyle(metric == "Focus Score" ? AppColors.accent : AppColors.textMuted.opacity(0.5))
                        .cornerRadius(3)
                        .position(by: .value("Metric", metric))
                }
                .chartXScale(domain: 0...100)
                .chartXAxis { AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(AppColors.border)
                    AxisValueLabel().foregroundStyle(AppColors.textMuted)
                } }
                .chartYAxis { AxisMarks { _ in
                    AxisValueLabel().font(.system(size: 11)).foregroundStyle(AppColors.textSecondary)
                } }
                .chartForegroundStyleScale([
                    "Focus Score": AppColors.accent,
                    "Study Hours/wk": AppColors.textMuted.opacity(0.5),
                ])
                .chartLegend(position: .topLeading, spacing: 8)
                .frame(height: 200)
            }

            card("Focus Score vs Study Time — Correlation") {
                ZStack(alignment: .topLeading) {
                    GeometryReader { geo in
                        let xMin = 0.0, xMax = 25.0, yMin = 40.0, yMax = 95.0
                        let xScale = geo.size.width / (xMax - xMin)
                        let yScale = geo.size.height / (yMax - yMin)
                        let zoneX = CGFloat(10 - xMin) * xScale
                        let zoneW = CGFloat(5) * xScale
                        let zoneY = geo.size.height - CGFloat(85 - yMin) * yScale
                        let zoneH = CGFloat(85 - 75) * yScale

                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.accent.opacity(0.08))
                            .frame(width: zoneW, height: zoneH)
                            .offset(x: zoneX, y: zoneY)
                        Text("Optimal Zone")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(AppColors.accent.opacity(0.7))
                            .offset(x: zoneX + 2, y: zoneY - 14)
                    }
                    .frame(height: 250)

                    Chart(correlationData, id: \.hours) { item in
                        PointMark(
                            x: .value("Study Hours/Week", item.hours),
                            y: .value("Focus Score", item.focus)
                        )
                        .foregroundStyle(
                            item.hours >= 10 && item.hours <= 15
                                ? AppColors.accent : AppColors.textMuted.opacity(0.6)
                        )
                        .symbolSize(60)
                    }
                    .chartXScale(domain: 0...25)
                    .chartYScale(domain: 40...95)
                    .chartXAxisLabel("Study Hours per Week", alignment: .center)
                    .chartYAxisLabel("Avg Focus Score", position: .leading)
                    .chartXAxis { AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(AppColors.border)
                        AxisValueLabel().foregroundStyle(AppColors.textMuted)
                    } }
                    .chartYAxis { AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(AppColors.border)
                        AxisValueLabel().foregroundStyle(AppColors.textMuted)
                    } }
                    .frame(height: 250)
                }
                .frame(height: 250)

                Text("Students who study 10–15 hours per week show the highest focus scores. Beyond 15 hours, focus quality decreases — suggesting diminishing returns from excessive study time.")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.top, 6)
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
            RoundedRectangle(cornerRadius: 2).fill(level.color).frame(width: 4)
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
                Text(desc).font(.system(size: 10)).foregroundStyle(AppColors.textSecondary)
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
            switch self { case .red: return AppColors.danger; case .orange: return AppColors.warning; case .green: return AppColors.accent }
        }
        var label: String {
            switch self { case .red: return "High Risk"; case .orange: return "Monitor"; case .green: return "Resolved" }
        }
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
