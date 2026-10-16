import SwiftUI

@main
struct ToteelDriverApp: App {
    @StateObject private var service = ToteelSocketService(role: "driver")

    var body: some Scene {
        WindowGroup {
            DriverRootView()
                .environmentObject(service)
        }
    }
}
