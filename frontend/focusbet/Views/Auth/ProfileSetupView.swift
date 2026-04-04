import SwiftUI

struct ProfileSetupView: View {
    @AppStorage("isProfileComplete") private var isProfileComplete = false

    @State private var name = ""
    @State private var school = "Purdue University"
    @State private var major = ""
    @State private var year = ""
    @State private var expectedGraduation = ""
    @State private var gender = "Prefer not to say"

    private let years = ["Freshman", "Sophomore", "Junior", "Senior", "Graduate"]
    private let graduationOptions = [
        "Spring 2025", "Fall 2025",
        "Spring 2026", "Fall 2026",
        "Spring 2027", "Fall 2027",
        "Spring 2028", "Fall 2028",
        "Spring 2029",
    ]
    private let genderOptions = ["Female", "Male", "Prefer not to say"]

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("Complete Your Profile")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Help us personalize your experience")
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.top, 40)

                VStack(spacing: 24) {
                    // Name
                    fieldLabel("Name")
                    styledTextField("Enter your full name", text: $name)

                    // School
                    fieldLabel("School")
                    styledTextField("Search your university", text: $school)

                    // Major
                    fieldLabel("Major")
                    styledTextField("e.g. Computer Science", text: $major)

                    // Year
                    fieldLabel("Year")
                    HStack(spacing: 8) {
                        ForEach(years, id: \.self) { option in
                            chipButton(option, isSelected: year == option) { year = option }
                        }
                    }

                    // Expected Graduation
                    fieldLabel("Expected Graduation")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(graduationOptions, id: \.self) { option in
                                chipButton(option, isSelected: expectedGraduation == option) {
                                    expectedGraduation = option
                                }
                            }
                        }
                    }

                    // Gender
                    fieldLabel("Gender")
                    HStack(spacing: 8) {
                        ForEach(genderOptions, id: \.self) { option in
                            chipButton(option, isSelected: gender == option) { gender = option }
                        }
                    }
                }
                .padding(.horizontal, 40)

                Button {
                    // Save to UserDefaults
                    UserDefaults.standard.set(name.trimmingCharacters(in: .whitespaces), forKey: "userName")
                    UserDefaults.standard.set(school, forKey: "userSchool")
                    UserDefaults.standard.set(major, forKey: "userMajor")
                    UserDefaults.standard.set(year, forKey: "userYear")
                    UserDefaults.standard.set(expectedGraduation, forKey: "userGraduation")
                    UserDefaults.standard.set(gender, forKey: "userGender")
                    isProfileComplete = true
                } label: {
                    Text("Complete Setup")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isFormValid ? .white : AppColors.textMuted)
                        .frame(width: 280, height: 50)
                        .background(isFormValid ? AppColors.accent : AppColors.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
                }
                .buttonStyle(.plain)
                .disabled(!isFormValid)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bgPrimary)
    }

    // MARK: - Components

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func styledTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .foregroundStyle(AppColors.textPrimary)
            .padding(12)
            .background(AppColors.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }

    private func chipButton(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? AppColors.accent : AppColors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.accent.opacity(0.15) : AppColors.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? AppColors.accent : AppColors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
