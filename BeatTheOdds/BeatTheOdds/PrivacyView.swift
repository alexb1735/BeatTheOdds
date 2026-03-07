import SwiftUI

struct PrivacyView: View {
    var body: some View {
        List {
            Section("Privacy") {
                Button("Privacy Settings") {
                    Task { await ConsentManager.shared.showPrivacyOptions() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
        }
        .navigationTitle("Privacy")
    }
}

#Preview {
    NavigationStack { PrivacyView() }
}
