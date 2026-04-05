import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var school: String
    @State private var major: String
    @State private var year: String
    @State private var graduation: String
    @State private var gender: String

    private let years = ["Freshman", "Sophomore", "Junior", "Senior", "Graduate"]
    private let graduationOptions = [
        "Spring 2025", "Fall 2025",
        "Spring 2026", "Fall 2026",
        "Spring 2027", "Fall 2027",
        "Spring 2028", "Fall 2028",
        "Spring 2029",
    ]
    private let genderOptions = ["Female", "Male", "Prefer not to say"]

    init() {
        _name = State(initialValue: UserDefaults.standard.string(forKey: "userName") ?? "")
        _school = State(initialValue: UserDefaults.standard.string(forKey: "userSchool") ?? "Purdue University")
        _major = State(initialValue: UserDefaults.standard.string(forKey: "userMajor") ?? "")
        _year = State(initialValue: UserDefaults.standard.string(forKey: "userYear") ?? "")
        _graduation = State(initialValue: UserDefaults.standard.string(forKey: "userGraduation") ?? "")
        _gender = State(initialValue: UserDefaults.standard.string(forKey: "userGender") ?? "Prefer not to say")
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Text("Edit Profile")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.top, 24)

                VStack(spacing: 20) {
                    fieldLabel("Name")
                    styledTextField("Enter your full name", text: $name)

                    fieldLabel("School")
                    styledTextField("Search your university", text: $school)

                    fieldLabel("Major")
                    styledTextField("e.g. Computer Science", text: $major)

                    fieldLabel("Year")
                    HStack(spacing: 8) {
                        ForEach(years, id: \.self) { option in
                            chipButton(option, isSelected: year == option) { year = option }
                        }
                    }

                    fieldLabel("Expected Graduation")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(graduationOptions, id: \.self) { option in
                                chipButton(option, isSelected: graduation == option) {
                                    graduation = option
                                }
                            }
                        }
                    }

                    fieldLabel("Gender")
                    HStack(spacing: 8) {
                        ForEach(genderOptions, id: \.self) { option in
                            chipButton(option, isSelected: gender == option) { gender = option }
                        }
                    }
                }
                .padding(.horizontal, 32)

                HStack(spacing: 16) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.textMuted)
                            .frame(width: 120, height: 44)
                            .background(AppColors.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button {
                        let trimmedName = name.trimmingCharacters(in: .whitespaces)
                        // Save to UserDefaults immediately so UI updates without waiting for the network
                        UserDefaults.standard.set(trimmedName,  forKey: "userName")
                        UserDefaults.standard.set(school,       forKey: "userSchool")
                        UserDefaults.standard.set(major,        forKey: "userMajor")
                        UserDefaults.standard.set(year,         forKey: "userYear")
                        UserDefaults.standard.set(graduation,   forKey: "userGraduation")
                        UserDefaults.standard.set(gender,       forKey: "userGender")
                        // Persist to backend in the background
                        Task {
                            do {
                                try await APIService.shared.saveProfile(
                                    name: trimmedName, school: school, major: major,
                                    year: year, expectedGraduation: graduation, gender: gender
                                )
                            } catch {
                                print("[EditProfileView] saveProfile error: \(error.localizedDescription)")
                            }
                        }
                        dismiss()
                    } label: {
                        Text("Save Changes")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isFormValid ? .white : AppColors.textMuted)
                            .frame(width: 160, height: 44)
                            .background(isFormValid ? AppColors.accent : AppColors.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isFormValid)
                }
                .padding(.bottom, 24)
            }
        }
        .frame(width: 500, height: 580)
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
