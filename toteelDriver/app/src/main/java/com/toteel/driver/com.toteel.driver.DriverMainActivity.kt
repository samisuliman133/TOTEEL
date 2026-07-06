package com.toteel.driver


import org.osmdroid.views.overlay.Polyline
import android.Manifest
import org.osmdroid.views.MapView
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.config.Configuration
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.app.ActivityCompat
import com.google.android.gms.location.*
import android.os.Looper
import org.json.JSONObject
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import io.socket.client.IO
import io.socket.client.Socket
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.overlay.Marker
class DriverMainActivity : ComponentActivity() {

    private val SERVER_URL = "http://192.168.100.28:5000"
    private lateinit var socket: Socket
    private lateinit var fusedLocationClient: FusedLocationProviderClient

    private var driverLat by mutableStateOf(0.0)
    private var driverLng by mutableStateOf(0.0)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Configuration
            .getInstance()
            .load(
                applicationContext,
                getPreferences(
                    MODE_PRIVATE
                )
            )

        socket = IO.socket(SERVER_URL)
        fusedLocationClient =
            LocationServices.getFusedLocationProviderClient(this)

        ActivityCompat.requestPermissions(
            this,
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION
            ),
            100
        )
        val locationRequest =
            LocationRequest.Builder(
                Priority.PRIORITY_HIGH_ACCURACY,
                2000
            ).build()
        val locationCallback =
            object : LocationCallback() {

                override fun onLocationResult(
                    result: LocationResult
                ) {


                    val location =
                        result.lastLocation
                            ?: return

                    driverLat = location.latitude
                    driverLng = location.longitude

                    Log.d(
                        "DRIVER",
                        "GPS: ${location.latitude}, ${location.longitude}"
                    )
                    val data = JSONObject()



                    data.put(
                        "lat",
                        location.latitude
                    )

                    data.put(
                        "lng",
                        location.longitude
                    )

                    socket.emit(
                        "live_location",
                        data
                    )
                }

            }

        if (
            ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {

            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                Looper.getMainLooper()
            )
        }

        setContent {
            MaterialTheme {
                DriverScreen(socket)
            }
        }
        }
    @Composable
    fun DriverScreen(socket: Socket) {

        var status by remember { mutableStateOf("Waiting for Ride Request") }
        var requestReceived by remember { mutableStateOf(false) }

        var rideState by remember { mutableStateOf("REQUESTED") }

        var tripFare by remember {
            mutableStateOf("0.00")
        }

        var tripDistance by remember {
            mutableStateOf("0.000")
        }

        var tripMinutes by remember {
            mutableStateOf("0.0")
        }

        var driverLat by remember {
            mutableStateOf(0.0)
        }

        var driverLng by remember {
            mutableStateOf(0.0)
        }
        val mapView = remember {
            mutableStateOf<MapView?>(null)
        }

        val driverMarker = remember {
            mutableStateOf<Marker?>(null)
        }

        val riderMarker = remember {
            mutableStateOf<Marker?>(null)
        }

        val roadLine = remember {
            mutableStateOf<Polyline?>(null)
        }


        DisposableEffect(Unit) {

            Log.d("DRIVER", "DRIVER SCREEN STARTED")

            socket.on(Socket.EVENT_CONNECT) {
                Log.d("DRIVER", "CONNECTED")
            }

            socket.on("ride_received") {
                Log.d("DRIVER", "ride_received")

                requestReceived = true
                rideState = "REQUESTED"
                status = "Ride Request Received"
            }

            socket.on("driver_arrived") {

                Log.d("DRIVER", "driver_arrived RECEIVED")

                runOnUiThread {

                    requestReceived = true
                    rideState = "ARRIVED"
                    status = "Driver Arrived"

                }

            }

            socket.on("trip_completed") {

                Log.d("DRIVER", "trip_completed RECEIVED")

                val data = it[0] as JSONObject

                tripFare =
                    String.format(
                        "%.2f",
                        data.getDouble("fare")
                    )

                tripDistance =
                    String.format(
                        "%.3f",
                        data.getDouble("distanceKm")
                    )

                tripMinutes =
                    String.format(
                        "%.1f",
                        data.getDouble("tripMinutes")
                    )

                rideState = "COMPLETED"

                status =
                    "Trip Completed\n" +
                            "Distance: $tripDistance km\n" +
                            "Time: $tripMinutes min\n" +
                            "Fare: $tripFare EGP"

            }

            socket.connect()

            onDispose {
                socket.off("ride_received")
                socket.off("driver_arrived")
                socket.off("trip_completed")
                socket.off(Socket.EVENT_CONNECT)
            }
        }

        Box(
            modifier = Modifier.fillMaxSize()
        ) {

            AndroidView(

                factory = { context ->

                    val map = MapView(context).apply {
                        layoutParams = android.widget.FrameLayout.LayoutParams(
                            android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                            android.widget.FrameLayout.LayoutParams.MATCH_PARENT
                        )
                    }
                    Log.d("MAP", "MapView CREATED")
                    mapView.value = map

                    map.setTileSource(
                        TileSourceFactory.MAPNIK
                    )

                    map.setMultiTouchControls(true)

                    map.controller.setZoom(21.0)

                    map.controller.setCenter(
                        GeoPoint(
                            30.08031,
                            31.64417
                        )
                    )

                    val marker = Marker(map)

                    driverMarker.value = marker

                    marker.title = "Driver"

                    marker.setAnchor(
                        Marker.ANCHOR_CENTER,
                        Marker.ANCHOR_BOTTOM
                    )

                    marker.position = GeoPoint(
                        30.0444,
                        31.2357
                    )

                    map.controller.setCenter(
                        GeoPoint(30.0444, 31.2357)
                    )

                    map.invalidate()

                    map.overlays.add(marker)

                    map

                },

                update = { map ->

                    val driverPoint = GeoPoint(
                        driverLat,
                        driverLng
                    )

                    driverMarker.value?.let {

                        it.position = driverPoint
                        it.title = "Driver"

                        if (!map.overlays.contains(it)) {
                            map.overlays.add(it)
                        }

                    }

                    map.controller.animateTo(driverPoint)

                    map.invalidate()


                },

                modifier = Modifier.fillMaxSize()

            )

            Column(

                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 40.dp, start = 16.dp, end = 16.dp),

                verticalArrangement = Arrangement.Top,

                horizontalAlignment = Alignment.CenterHorizontally

            ) {

                Text(

                    text = status,

                    style = MaterialTheme.typography.titleLarge

                )

                Spacer(
                    modifier = Modifier.height(20.dp)
                )

                Spacer(modifier = Modifier.height(20.dp))

                if (!requestReceived) {

                    Text("No active request")

                } else {

                    when (rideState) {

                        "REQUESTED" -> Text("Incoming request...")

                        "ACCEPTED" -> Text("Driving to pickup...")

                        "ARRIVED" -> Text("Driver arrived")

                        "STARTED" -> Text("Trip in progress...")

                        "COMPLETED" -> {}

                    }

                    Spacer(modifier = Modifier.height(20.dp))

                    if (rideState == "REQUESTED") {

                        Button(
                            onClick = {
                                socket.emit("ride_accepted")
                                rideState = "ACCEPTED"
                                status = "Ride Accepted"
                            }
                        ) {
                            Text("Accept")
                        }

                        Spacer(modifier = Modifier.height(10.dp))

                        Button(
                            onClick = {
                                socket.emit("ride_rejected")
                                status = "Ride Rejected"
                            }
                        ) {
                            Text("Reject")
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    if (rideState == "ACCEPTED") {

                        Button(
                            onClick = {
                                socket.emit("driver_arrived")
                                rideState = "ARRIVED"
                                status = "Driver Arrived"
                            }
                        ) {
                            Text("Arrived")
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    if (rideState == "ARRIVED") {

                        Button(
                            onClick = {
                                socket.emit("trip_started")
                                rideState = "STARTED"
                                status = "Trip Started"
                            }
                        ) {
                            Text("Start Trip")
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    if (rideState == "STARTED") {

                        Button(
                            onClick = {
                                socket.emit("trip_completed")

                            }
                        ) {
                            Text("End Trip")
                        }
                    }
                }
            }
        }
    }
}

