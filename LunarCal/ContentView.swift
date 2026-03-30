import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            CalendarContainerView()
                .navigationBarHidden(true)
        }
    }
}

#Preview {
    ContentView()
}
