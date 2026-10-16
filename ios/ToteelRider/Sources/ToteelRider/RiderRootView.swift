import SwiftUI
import MapKit

struct RiderRootView: View {
    @EnvironmentObject private var service: ToteelSocketService
    @StateObject private var location = LocationStore()
    @State private var phone = ""
    @State private var password = ""
    @State private var fullName = ""
    @State private var destination = ""
    @State private var bidAmount = ""
    @State private var chatDraft = ""
    @State private var creatingAccount = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 15.5007, longitude: 32.5599),
        span: MKCoordinateSpan(latitudeDelta: 0.035, longitudeDelta: 0.035)
    )

    private var pickupPins: [PickupPin] {
        guard let lat = location.latitude, let lng = location.longitude else { return [] }
        return [PickupPin(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))]
    }

    var body: some View {
        NavigationStack {
            Group {
                if service.user == nil {
                    authenticationView
                } else {
                    rideView
                }
            }
            .navigationTitle("Toteel Rider Sudan")
            .toolbar {
                if service.user != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Sign out") { service.signOut() }
                    }
                }
            }
        }
    }

    private var authenticationView: some View {
        Form {
            Section {
                Text(service.statusMessage).font(.footnote).foregroundStyle(.secondary)
                TextField("Phone number", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
                if creatingAccount { TextField("Your name", text: $fullName).textContentType(.name) }
                SecureField("Password", text: $password).textContentType(creatingAccount ? .newPassword : .password)
                Button(creatingAccount ? "Create Rider Account" : "Sign in") {
                    if creatingAccount { service.registerRider(name: fullName, phone: phone, password: password) }
                    else { service.login(phone: phone, password: password) }
                }
                .disabled(!service.connected || phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || (creatingAccount && fullName.isEmpty))
                Button(creatingAccount ? "I already have an account" : "Create a Rider account") { creatingAccount.toggle() }
                    .font(.footnote)
            }
            if !service.errorMessage.isEmpty { Section("Message") { Text(service.errorMessage).foregroundStyle(.red) } }
            Section {
                Text("Sudan service · prices in SDG").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var rideView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(service.statusMessage).font(.footnote).foregroundStyle(.secondary)
                Map(coordinateRegion: $mapRegion, annotationItems: pickupPins) { pin in
                    MapMarker(coordinate: pin.coordinate, tint: .green)
                }
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onChange(of: location.latitude) { latitude in
                    if let latitude = latitude, let longitude = location.longitude {
                        mapRegion.center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pickup location").font(.headline)
                        Text(location.message).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Use my location") { location.requestLocation() }
                        .buttonStyle(.bordered)
                }
                TextField("Destination address in Sudan", text: $destination, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                TextField("Your offer in SDG (optional)", text: $bidAmount)
                    .keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                if let fare = service.estimatedFare { Text("Estimated fare: \(fare, specifier: "%.2f") SDG").font(.headline) }
                Button {
                    guard let lat = location.latitude, let lng = location.longitude else {
                        service.errorMessage = "Tap Use my location and allow location access first"; return
                    }
                    service.requestRide(latitude: lat, longitude: lng, destinationAddress: destination,
                                        bidAmount: Double(bidAmount.replacingOccurrences(of: ",", with: ".")))
                } label: {
                    Label("FIND DRIVERS", systemImage: "car.fill").frame(maxWidth: .infinity).padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)

                if !service.offers.isEmpty {
                    Text("Driver offers").font(.title3.bold())
                    ForEach(Array(service.offers.enumerated()), id: \.offset) { item in
                        offerCard(item.element)
                    }
                }

                if !service.tripStatus.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trip status: \(service.tripStatus)").font(.headline)
                        Button("Cancel trip") { service.cancelTrip() }.buttonStyle(.bordered)
                    }
                }

                if !service.activeOfferId.isEmpty {
                    chatPanel
                }
                if !service.errorMessage.isEmpty {
                    Text(service.errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            .padding()
        }
    }

    private func offerCard(_ offer: [String: Any]) -> some View {
        let name = offer["driverName"] as? String ?? "Driver"
        let amount = (offer["offerAmount"] as? NSNumber)?.doubleValue ?? 0
        let model = offer["carModel"] as? String ?? ""
        let offerId = offer["offerId"] as? String ?? ""
        return VStack(alignment: .leading, spacing: 8) {
            Text(name).font(.headline)
            if !model.isEmpty { Text(model).font(.subheadline).foregroundStyle(.secondary) }
            Text(String(format: "Offer: %.2f SDG", amount)).font(.title3.bold())
            HStack {
                Button("Accept") { service.acceptOffer(offer) }.buttonStyle(.borderedProminent)
                Button("Chat") { service.activeOfferId = offerId }.buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var chatPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Private Rider–Driver chat").font(.headline)
            ForEach(Array(service.chatMessages.enumerated()), id: \.offset) { item in
                let message = item.element
                if (message["offerId"] as? String ?? "") == service.activeOfferId {
                    Text("\(message["from"] as? String ?? "") : \(message["text"] as? String ?? "")")
                        .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HStack {
                TextField("Message…", text: $chatDraft, axis: .vertical).textFieldStyle(.roundedBorder)
                Button("Send") {
                    service.sendChat(chatDraft)
                    chatDraft = ""
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding().background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct PickupPin: Identifiable {
    let id = "pickup"
    let coordinate: CLLocationCoordinate2D
}
