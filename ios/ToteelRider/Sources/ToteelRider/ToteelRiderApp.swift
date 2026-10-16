import SwiftUI

@main
struct ToteelRiderApp: App {
    @StateObject private var service = ToteelSocketService(role: "rider")

    var body: some Scene {
        WindowGroup {
            RiderRootView()
                .environmentObject(service)
        }
    }
}
