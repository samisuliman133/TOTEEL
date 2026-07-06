const express = require("express");
const http = require("http");
const cors = require("cors");
const { Server } = require("socket.io");

const app = express();

app.use(cors());
app.use(express.json());

const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: "*"
  }
});

app.get("/", (req, res) => {
  res.send("🚖 Toteel Backend Running");
});

app.post("/request", (req, res) => {

  console.log("Ride Request Received");

  io.emit("ride_received", {
    timestamp: Date.now()
  });

  res.status(200).json({
    success: true
  });
});

let pickupLocation = null;

let tripStarted = false;

let currentTrip = {

  active: false,

  rider: null,

  driver: "Driver 1",

  startTime: 0,

  endTime: 0,

  distanceMeters: 0,

  fare: 0,

  waitingSeconds: 0

};

let previousDriverLocation = null;

let tripDistanceMeters = 0;

let tripStartTime = 0;



io.on("connection", (socket) => {

  console.log("User connected:", socket.id);


  socket.on("ride_accepted", () => {

    console.log("EVENT: ride_accepted");
    console.log("Ride Accepted by Driver");

    io.emit("driver_accepted");

  });

 socket.on("ride_rejected", () => {

  console.log("EVENT: ride_rejected");
  console.log("Ride Rejected by Driver");

  io.emit("driver_rejected");

});

socket.on("driver_arrived", () => {

  console.log("EVENT: driver_arrived");

  io.emit("driver_arrived");

});

socket.on("trip_started", () => {

  console.log("EVENT: trip_started");

  tripStarted = true;

  tripDistanceMeters = 0;

  previousDriverLocation = null;

  tripStartTime = Date.now();

  currentTrip.active = true;
  currentTrip.startTime = tripStartTime;
  currentTrip.distanceMeters = 0;
  currentTrip.fare = 0;

  io.emit("trip_started");

});socket.on("trip_completed", () => {

  console.log("EVENT: trip_completed");

  tripStarted = false;
  pickupLocation = null;

  currentTrip.active = false;

  currentTrip.endTime = Date.now();

  const tripTimeMinutes =
    (currentTrip.endTime - currentTrip.startTime) / 60000;

  const tripDistanceKm =
    tripDistanceMeters / 1000;

  const hour = new Date().getHours();

  const rate =
    (hour >= 14 && hour < 20)
      ? 5
      : 4;

  const fare =
    tripDistanceKm * rate;

  currentTrip.fare = fare;

  console.log("--------------------------------");

  console.log(
    "Trip Distance:",
    tripDistanceKm.toFixed(3),
    "km"
  );

  console.log(
    "Trip Time:",
    tripTimeMinutes.toFixed(1),
    "min"
  );

  console.log(
    "Fare:",
    fare.toFixed(2),
    "EGP"
  );

  console.log("--------------------------------");

  io.emit("trip_completed", {

    distanceKm: tripDistanceKm,

    tripMinutes: tripTimeMinutes,

    fare: fare

  });

});

socket.on("live_location", (data) => {

  console.log("EVENT: driver_location", data);

  if (tripStarted) {

    if (previousDriverLocation != null) {

      const lat1 = previousDriverLocation.lat;
      const lon1 = previousDriverLocation.lng;

      const lat2 = data.lat;
      const lon2 = data.lng;

      const R = 6371000;

      const dLat = (lat2 - lat1) * Math.PI / 180;
      const dLon = (lon2 - lon1) * Math.PI / 180;

      const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(lat1 * Math.PI / 180) *
        Math.cos(lat2 * Math.PI / 180) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);

      const c =
        2 * Math.atan2(
          Math.sqrt(a),
          Math.sqrt(1 - a)
        );

      const meters = R * c;

      if (meters >= 1) {

        tripDistanceMeters += meters;

        currentTrip.distanceMeters =
          tripDistanceMeters;

        console.log(
          "Trip Distance:",
          tripDistanceMeters.toFixed(2),
          "m"
        );
      }

    }

    if (pickupLocation != null) {

  const lat1 = pickupLocation.lat;
  const lon1 = pickupLocation.lng;

  const lat2 = data.lat;
  const lon2 = data.lng;

  const R = 6371000;

  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) *
    Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) *
    Math.sin(dLon / 2);

  const c =
    2 * Math.atan2(
      Math.sqrt(a),
      Math.sqrt(1 - a)
    );

  const distanceToPickup = R * c;

  if (distanceToPickup <= 15) {

    console.log("AUTO ARRIVED");

    io.emit("driver_arrived");

    pickupLocation = null;

  }

}
  }

  io.emit("live_location", data);

});
});

server.listen(5000, () => {

  console.log("🚀 Server running on port 5000");

});



