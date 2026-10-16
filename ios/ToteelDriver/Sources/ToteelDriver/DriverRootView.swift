import SwiftUI

struct DriverRootView: View {
    @EnvironmentObject private var service: ToteelSocketService
    @StateObject private var location = LocationStore()
    @State private var phone = ""
    @State private var driverCode = ""
    @State private var offerAmount = "150"
    @State private var chatDraft = ""

    var body: some View {
        NavigationStack {
            Group {
                if service.user == nil { loginView }
                else { driverView }
            }
            .navigationTitle("Toteel Driver Sudan")
            .toolbar {
                if service.user != nil {
                    ToolbarItem(placement: .topBarTrailing) { Button("Sign out") { service.signOut() } }
                }
            }
        }
    }

    private var loginView: some View {
        Form {
            Section("Driver sign in") {
                Text(service.statusMessage).font(.footnote).foregroundStyle(.secondary)
                TextField("Registered phone number", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
                SecureField("4-character Driver code", text: $driverCode).textInputAutocapitalization(.characters).autocorrectionDisabled()
                Button("Sign in") { service.login(phone: phone, password: driverCode.uppercased()) }
                    .disabled(!service.connected || phone.isEmpty || driverCode.count != 4)
                Text("Driver accounts must be created by Toteel administration.").font(.footnote).foregroundStyle(.secondary)
            }
            if !service.errorMessage.isEmpty { Section("Message") { Text(service.errorMessage).foregroundStyle(.red) } }
        }
    }

    private var driverView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(service.statusMessage).font(.footnote).foregroundStyle(.secondary)
                if let driverId = service.user?["driverId"] as? String { Text("Driver ID: \(driverId)").font(.headline) }
                HStack {
                    VStack(alignment: .leading) {
                        Text("Your location").font(.headline)
                        Text(location.message).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Enable location") { location.start() }.buttonStyle(.borderedProminent)
                }

                if let request = service.incomingRequest {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("New ride request").font(.title2.bold())
                        Text("Rider: \(request["rider"] as? String ?? "Rider")")
                        if let pickup = request["pickup"] as? [String: Any] {
                            Text("Pickup: \(pickup["address"] as? String ?? "Location received")")
                        }
                        if let dropoff = request["dropoff"] as? [String: Any] {
                            Text("Destination: \(dropoff["address"] as? String ?? "Destination received")")
                        }
                        if let bid = request["riderBid"] as? NSNumber { Text("Rider offer: \(bid.doubleValue, specifier: "%.2f") SDG") }
                        TextField("Offer amount in SDG", text: $offerAmount).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                        Button("Accept rider's rate") {
                            let riderBid = (request["riderBid"] as? NSNumber)?.doubleValue
                            let amount = riderBid ?? (Double(offerAmount) ?? 150)
                            service.submitDriverOffer(amount: amount, action: "accept")
                        }.buttonStyle(.borderedProminent)
                        Button("Send counter-offer") {
                            service.submitDriverOffer(amount: Double(offerAmount.replacingOccurrences(of: ",", with: ".")) ?? 0, action: "counter")
                        }.buttonStyle(.bordered)
                        Button("Hide request on this phone") { service.dismissLocalRequest() }.font(.footnote)
                        Text("Hiding is local only; it does not reject or cancel the Rider's trip.").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
                }

                if let trip = service.acceptedTrip {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Accepted trip").font(.title2.bold())
                        Text("Rider: \(trip["rider"] as? String ?? "Rider")")
                        Text("Status: \(service.tripStatus.isEmpty ? "Accepted" : service.tripStatus)")
                        Button("Driver arrived at pickup") { service.markDriverArrived() }.buttonStyle(.borderedProminent)
                        Button("Start trip") { service.startTrip() }.buttonStyle(.borderedProminent)
                        Button("Complete trip") { service.completeTrip() }.buttonStyle(.borderedProminent)
                        Button("Cancel trip") { service.cancelTrip() }.buttonStyle(.bordered)
                    }
                    .padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
                }

                if !service.activeOfferId.isEmpty { chatPanel }
                if !service.errorMessage.isEmpty { Text(service.errorMessage).foregroundStyle(.red).font(.footnote) }
            }
            .padding()
        }
        .onAppear { location.start() }
        .onChange(of: location.latitude) { newValue in
            guard let lat = newValue, let lng = location.longitude else { return }
            service.updateDriverLocation(latitude: lat, longitude: lng)
        }
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
                Button("Send") { service.sendChat(chatDraft); chatDraft = "" }.buttonStyle(.borderedProminent)
            }
        }
        .padding().background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
