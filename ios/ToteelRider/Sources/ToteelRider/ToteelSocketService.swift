import Foundation
import Combine
import SocketIO
import AudioToolbox

/// Socket.IO bridge for the existing Sudan backend. This intentionally does not alter the server.
final class ToteelSocketService: ObservableObject {
    static let serverURL = URL(string: "http://46.4.202.163:3001")!

    @Published var connected = false
    @Published var registered = false
    @Published var user: [String: Any]?
    @Published var errorMessage = ""
    @Published var statusMessage = "Connecting to Toteel Sudan…"
    @Published var estimatedFare: Double?
    @Published var offers: [[String: Any]] = []
    @Published var incomingRequest: [String: Any]?
    @Published var acceptedTrip: [String: Any]?
    @Published var tripStatus = ""
    @Published var activeOfferId = ""
    @Published var chatMessages: [[String: Any]] = []

    private let role: String
    private let manager: SocketManager
    private let socket: SocketIOClient
    private var pendingRideRequest = false
    private var pendingBidAmount: Double?

    init(role: String) {
        self.role = role
        self.manager = SocketManager(socketURL: Self.serverURL, config: [
            .log(false), .compress, .reconnects(true), .reconnectAttempts(-1),
            .reconnectWait(5), .handleQueue(DispatchQueue.main)
        ])
        self.socket = manager.defaultSocket
        installHandlers()
        socket.connect()
    }

    private func installHandlers() {
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            guard let self = self else { return }
            self.connected = true
            self.statusMessage = "Connected to Sudan server"
            self.restoreSessionIfPossible()
        }
        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            self?.connected = false
            self?.registered = false
            self?.statusMessage = "Disconnected — reconnecting…"
        }
        socket.on("auth_logged_in") { [weak self] data, _ in self?.handleAuthSuccess(data) }
        socket.on("auth_registered") { [weak self] data, _ in self?.handleAuthSuccess(data) }
        socket.on("auth_verified") { [weak self] data, _ in
            guard let self = self, let payload = data.first as? [String: Any] else { return }
            if (payload["valid"] as? Bool) == true, let user = payload["user"] as? [String: Any], (user["type"] as? String) == self.role {
                self.user = user
                self.registerSocketIdentity()
            } else {
                self.user = nil
                self.statusMessage = "Please sign in again"
            }
        }
        socket.on("auth_error") { [weak self] data, _ in
            guard let payload = data.first as? [String: Any] else { return }
            self?.errorMessage = payload["msg"] as? String ?? "Authentication failed"
        }
        socket.on("registered") { [weak self] data, _ in
            guard let self = self, let payload = data.first as? [String: Any] else { return }
            self.registered = (payload["success"] as? Bool) == true
            if self.registered {
                self.statusMessage = "Ready — \(payload["name"] as? String ?? self.role)"
            } else {
                self.errorMessage = payload["message"] as? String ?? "Server registration failed"
            }
        }
        socket.on("account_suspended") { [weak self] data, _ in
            let payload = data.first as? [String: Any]
            self?.errorMessage = payload?["message"] as? String ?? "This account is suspended"
        }
        socket.on("fare_estimate") { [weak self] data, _ in
            guard let payload = data.first as? [String: Any] else { return }
            self?.estimatedFare = (payload["fare"] as? NSNumber)?.doubleValue
                ?? (payload["estimatedFare"] as? NSNumber)?.doubleValue
        }
        socket.on("destination_error") { [weak self] data, _ in
            let payload = data.first as? [String: Any]
            self?.pendingRideRequest = false
            self?.errorMessage = payload?["error"] as? String ?? "Destination could not be found"
        }
        socket.on("ride_error") { [weak self] data, _ in
            let payload = data.first as? [String: Any]
            self?.pendingRideRequest = false
            self?.errorMessage = payload?["message"] as? String ?? "Ride request failed"
        }
        socket.on("destination_set") { [weak self] _ , _ in
            guard let self = self, self.pendingRideRequest else { return }
            self.pendingRideRequest = false
            var payload: [String: Any] = ["riderName": self.user?["name"] as? String ?? "Rider"]
            if let bid = self.pendingBidAmount, bid > 0 { payload["bidAmount"] = bid }
            self.socket.emit("request_ride", payload)
            self.statusMessage = "Ride requested — waiting for offers"
        }
        socket.on("ride_requested") { [weak self] data, _ in
            guard let payload = data.first as? [String: Any] else { return }
            if let fare = payload["estimatedFare"] as? NSNumber { self?.estimatedFare = fare.doubleValue }
            self?.statusMessage = "Ride request sent"
        }
        socket.on("new_offer") { [weak self] data, _ in
            guard let self = self, let payload = data.first as? [String: Any] else { return }
            let id = payload["offerId"] as? String ?? ""
            if !self.offers.contains(where: { ($0["offerId"] as? String) == id }) { self.offers.append(payload) }
            self.statusMessage = "New Driver offer received"
        }
        socket.on("new_ride_request") { [weak self] data, _ in
            guard let self = self else { return }
            self.incomingRequest = data.first as? [String: Any]
            self.statusMessage = "New nearby ride request"
        }
        socket.on("offer_sent") { [weak self] data, _ in
            guard let self = self, let payload = data.first as? [String: Any] else { return }
            if let offer = payload["offer"] as? [String: Any], let offerId = offer["offerId"] as? String {
                self.activeOfferId = offerId
            }
            self.statusMessage = "Offer sent to Rider"
        }
        socket.on("offer_error") { [weak self] data, _ in
            let payload = data.first as? [String: Any]
            self?.errorMessage = payload?["message"] as? String ?? "Offer failed"
        }
        socket.on("ride_accepted") { [weak self] data, _ in
            guard let self = self, let payload = data.first as? [String: Any] else { return }
            self.acceptedTrip = payload
            self.tripStatus = "accepted"
            if let offerId = payload["offerId"] as? String { self.activeOfferId = offerId }
            self.statusMessage = "Ride accepted"
        }
        socket.on("driver_arrived") { [weak self] _ , _ in self?.tripStatus = "Driver arrived" }
        socket.on("trip_started") { [weak self] _ , _ in self?.tripStatus = "Trip in progress" }
        socket.on("trip_completed") { [weak self] _ , _ in
            self?.tripStatus = "Trip completed"
            self?.statusMessage = "Trip completed"
            self?.acceptedTrip = nil
            self?.incomingRequest = nil
        }
        socket.on("trip_cancelled") { [weak self] _ , _ in
            self?.tripStatus = "Trip cancelled"
            self?.acceptedTrip = nil
            self?.incomingRequest = nil
        }
        socket.on("trip_state") { [weak self] data, _ in
            guard let payload = data.first as? [String: Any] else { return }
            self?.tripStatus = payload["status"] as? String ?? "Trip active"
        }
        socket.on("chat_message") { [weak self] data, _ in
            guard let self = self, let payload = data.first as? [String: Any] else { return }
            let offerId = payload["offerId"] as? String ?? ""
            if self.activeOfferId.isEmpty || offerId == self.activeOfferId { self.chatMessages.append(payload) }
            AudioServicesPlaySystemSound(1007)
        }
        socket.on("chat_error") { [weak self] data, _ in
            let payload = data.first as? [String: Any]
            self?.errorMessage = payload?["message"] as? String ?? "Message was not delivered"
        }
        socket.on("chat_message_sent") { [weak self] _ , _ in self?.errorMessage = "" }
        socket.on("ride_rejected") { [weak self] _ , _ in
            self?.statusMessage = "Ride request was rejected"
            self?.incomingRequest = nil
        }
    }

    func login(phone: String, password: String) {
        errorMessage = ""
        guard connected else { errorMessage = "Not connected to the Sudan server yet"; return }
        socket.emit("auth_login", ["phone": phone.trimmingCharacters(in: .whitespacesAndNewlines), "password": password])
    }

    func registerRider(name: String, phone: String, password: String) {
        errorMessage = ""
        guard role == "rider" else { errorMessage = "Driver accounts are created by Toteel administration"; return }
        socket.emit("auth_register", ["phone": phone.trimmingCharacters(in: .whitespacesAndNewlines), "password": password, "type": "rider", "name": name])
    }

    private func handleAuthSuccess(_ data: [Any]) {
        guard let payload = data.first as? [String: Any],
              (payload["success"] as? Bool) == true,
              let user = payload["user"] as? [String: Any] else { return }
        guard (user["type"] as? String) == role else {
            errorMessage = "This account is not a Rider account."
            self.user = nil
            return
        }
        self.user = user
        if let token = payload["token"] as? String, let phone = user["phone"] as? String {
            UserDefaults.standard.set(token, forKey: "toteel.\(role).token")
            UserDefaults.standard.set(phone, forKey: "toteel.\(role).phone")
        }
        errorMessage = ""
        registerSocketIdentity()
    }

    private func restoreSessionIfPossible() {
        let token = UserDefaults.standard.string(forKey: "toteel.\(role).token") ?? ""
        let phone = UserDefaults.standard.string(forKey: "toteel.\(role).phone") ?? ""
        if !token.isEmpty && !phone.isEmpty { socket.emit("auth_verify", ["phone": phone, "token": token]) }
    }

    private func registerSocketIdentity() {
        guard let user = user else { return }
        var payload: [String: Any] = ["role": role, "name": user["name"] as? String ?? (role == "driver" ? "Driver" : "Rider"), "phone": user["phone"] as? String ?? ""]
        if role == "driver", let driverId = user["driverId"] as? String { payload["driverId"] = driverId }
        socket.emit("register", payload)
    }

    func requestRide(latitude: Double, longitude: Double, destinationAddress: String, bidAmount: Double?) {
        guard registered else { errorMessage = "Sign in and wait for Ready status first"; return }
        guard !destinationAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { errorMessage = "Enter a destination address"; return }
        errorMessage = ""
        offers = []
        pendingBidAmount = bidAmount
        pendingRideRequest = true
        socket.emit("set_pickup", ["lat": latitude, "lng": longitude, "address": "Current location"])
        socket.emit("set_destination", ["address": destinationAddress])
    }

    func acceptOffer(_ offer: [String: Any]) {
        guard let offerId = offer["offerId"] as? String else { return }
        activeOfferId = offerId
        socket.emit("accept_offer", ["driverName": offer["driverName"] as? String ?? "Driver", "offerId": offerId])
    }

    func submitDriverOffer(amount: Double, action: String) {
        guard amount > 0 else { errorMessage = "Enter a valid offer amount"; return }
        socket.emit("driver_offer", ["offerAmount": amount, "action": action])
    }

    func updateDriverLocation(latitude: Double, longitude: Double) {
        guard registered, role == "driver" else { return }
        socket.emit("driver_location", ["lat": latitude, "lng": longitude])
    }

    func sendChat(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !activeOfferId.isEmpty else { errorMessage = "Choose a Driver offer before chatting"; return }
        socket.emit("chat_message", ["offerId": activeOfferId, "text": trimmed])
        chatMessages.append(["offerId": activeOfferId, "from": user?["name"] as? String ?? role, "fromRole": role, "text": trimmed, "timestamp": Date().timeIntervalSince1970 * 1000])
    }

    func markDriverArrived() { socket.emit("driver_arrived") }
    func startTrip() { socket.emit("start_trip") }
    func completeTrip() { socket.emit("complete_trip") }
    func cancelTrip() { socket.emit("cancel_trip", ["by": role]) }
    func dismissLocalRequest() { incomingRequest = nil }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: "toteel.\(role).token")
        UserDefaults.standard.removeObject(forKey: "toteel.\(role).phone")
        user = nil
        registered = false
        offers = []
        activeOfferId = ""
        chatMessages = []
        socket.disconnect()
        socket.connect()
    }
}
