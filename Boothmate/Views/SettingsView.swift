import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("음성인식 엔진") {
                    Text("Apple (기본)")
                }
                Section("글로서리") {
                    Text("글로서리 관리")
                }
            }
            .navigationTitle("설정")
        }
    }
}
