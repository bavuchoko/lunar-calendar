import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            CalendarContainerView()
                .navigationTitle("달력")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#Preview {
    ContentView()
}
