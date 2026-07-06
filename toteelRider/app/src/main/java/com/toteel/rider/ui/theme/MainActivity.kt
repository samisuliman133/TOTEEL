package com.toteel.rider

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Looper
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.app.ActivityCompat
import com.google.android.gms.location.*
import io.socket.client.IO
import io.socket.client.Socket
import okhttp3.*
import org.json.JSONObject
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import android.location.Location
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polyline

import java.io.IOException

class MainActivity : ComponentActivity() {


    private val SERVER_URL =
        "http://192.168.100.28:5000"

    private lateinit var socket:
            Socket

    private lateinit var
            fusedLocationClient:
            FusedLocationProviderClient

    override fun onCreate(
        savedInstanceState: Bundle?
    ) {

        super.onCreate(
            savedInstanceState
        )

        Configuration
            .getInstance()
            .load(
                applicationContext,
                getPreferences(
                    MODE_PRIVATE
                )
            )

        socket =
            IO.socket(
                SERVER_URL
            )

        socket.connect()

        fusedLocationClient =
            LocationServices
                .getFusedLocationProviderClient(
                    this
                )

        ActivityCompat.requestPermissions(
            this,
            arrayOf(
                Manifest.permission
                    .ACCESS_FINE_LOCATION
            ),
            100
        )

        setContent {

            MaterialTheme {

                RiderScreen(
                    socket = socket,
                    fusedLocationClient =
                        fusedLocationClient,

                    onRequestRide = {
                        sendRideRequest()
                    }
                )
            }
        }
    }

    private fun sendRideRequest() {

        val client =
            OkHttpClient.Builder()
                .retryOnConnectionFailure(
                    true
                )
                .build()


        val request =
            Request.Builder()
                .url(
                    "$SERVER_URL/request"
                )
                .post(
                    FormBody.Builder()
                        .add(
                            "rider",
                            "Sami Rider"
                        )
                        .build()
                )
                .build()

        client.newCall(
            request
        ).enqueue(
            object : Callback {

                override fun onFailure(
                    call: Call,
                    e: IOException
                ) {

                    runOnUiThread {

                        Toast.makeText(
                            this@MainActivity,
                            "Connection Failed",
                            Toast.LENGTH_SHORT
                        ).show()
                    }
                }

                override fun onResponse(
                    call: Call,
                    response: Response
                ) {

                    runOnUiThread {

                        Toast.makeText(
                            this@MainActivity,
                            "Ride Requested",
                            Toast.LENGTH_SHORT
                        ).show()
                    }
                }
            }
        )
    }


}

@Composable
fun RiderScreen(
    socket: Socket,
    fusedLocationClient:
    FusedLocationProviderClient,
    onRequestRide:
        () -> Unit
) {


    var rideStatus by remember {
        mutableStateOf(
            "Waiting..."
        )
    }

    var locationText by remember {
        mutableStateOf(
            "GPS waiting..."
        )
    }

    var riderLat by remember {
        mutableStateOf(
            30.0444
        )
    }

    var riderLng by remember {
        mutableStateOf(
            31.2357
        )
    }

    var driverLat by remember {
        mutableStateOf(
            0.0
        )
    }

    var driverLng by remember {
        mutableStateOf(
            0.0
        )
    }
    var distanceText by remember {


        mutableStateOf(
            "Driver distance: --"
        )
    }
    var tripStarted by remember {
        mutableStateOf(false)
    }

    var tripDistanceMeters by remember {
        mutableStateOf(0.0)
    }

    var previousTripLat by remember {
        mutableStateOf<Double?>(null)
    }

    var previousTripLng by remember {
        mutableStateOf<Double?>(null)
    }

    var etaText by remember {


        mutableStateOf(
            "ETA: --"
        )


    }

    var tripFare by remember {
        mutableStateOf("0.00")
    }

    var tripMinutes by remember {
        mutableStateOf("0.0")
    }

    var tripDistanceKm by remember {
        mutableStateOf("0.000")
    }


    LaunchedEffect(Unit) {

        socket.on(
            "driver_accepted"
        ) {

            rideStatus =
                "Ride Accepted"
        }

        socket.on(
            "driver_rejected"
        ) {

            rideStatus =
                "Ride Rejected"
        }

        socket.on(
            "driver_arrived"
        ) {

            rideStatus =
                "Driver Arrived"

        }

        socket.on(
            "trip_started"
        ) {

            tripStarted = true
            tripDistanceMeters = 0.0

            previousTripLat = riderLat
            previousTripLng = riderLng

            rideStatus =
                "Trip Started"

        }
        socket.on("trip_completed") {

            val data = it[0] as JSONObject

            tripStarted = false

            previousTripLat = null
            previousTripLng = null

            tripFare =
                String.format(
                    "%.2f",
                    data.getDouble("fare")
                )

            tripMinutes =
                String.format(
                    "%.1f",
                    data.getDouble("tripMinutes")
                )

            tripDistanceKm =
                String.format(
                    "%.3f",
                    data.getDouble("distanceKm")
                )

            rideStatus =
                "Trip Completed\n" +
                        "Distance: $tripDistanceKm km\n" +
                        "Time: $tripMinutes min\n" +
                        "Fare: $tripFare EGP"

        }

        socket.on("live_location") {

            val data = it[0] as JSONObject

            driverLat = data.getDouble("lat")
            driverLng = data.getDouble("lng")
            driverLng =
                data.getDouble(
                    "lng"
                )


            val results = FloatArray(1)

            Location.distanceBetween(
                riderLat,
                riderLng,
                driverLat,
                driverLng,
                results
            )

            val distanceKm = results[0] / 1000f
            val distanceMeters = results[0]



            if (distanceMeters < 1000) {

                distanceText =
                    "Driver: ${distanceMeters.toInt()} m away (Raw: ${String.format("%.2f", distanceMeters)})"

            } else {

                distanceText =
                    "Driver: " +
                            String.format("%.2f", distanceKm) +
                            " km away"

            }
            val etaMinutes =
                (distanceKm / 0.5)
                    .toInt()
                    .coerceAtLeast(1)

            etaText =
                "ETA: ~$etaMinutes min"

            if (
                distanceMeters <= 15 &&
                rideStatus == "Ride Accepted"
            ) {

                rideStatus =
                    "Driver Arrived"

            }

        }

    }

    val mapView = remember {
        mutableStateOf<MapView?>(null)
    }

    val riderMarker = remember {
        mutableStateOf<Marker?>(null)
    }

    val driverMarker = remember {
        mutableStateOf<Marker?>(null)
    }

    val roadLine = remember {
        mutableStateOf<Polyline?>(null)
    }

    AndroidView(
        factory = { context ->

            val map =
                MapView(
                    context
                )

            mapView.value = map

            map.setTileSource(
                TileSourceFactory
                    .MAPNIK
            )

            map.setMultiTouchControls(
                true
            )

            map.controller.setZoom(
                21.0
            )


            if (
                ActivityCompat
                    .checkSelfPermission(
                        context,
                        Manifest.permission
                            .ACCESS_FINE_LOCATION
                    )
                ==
                PackageManager
                    .PERMISSION_GRANTED
            ) {

                val request =
                    LocationRequest.Builder(
                        Priority
                            .PRIORITY_HIGH_ACCURACY,
                        1000
                    )
                        .setMinUpdateDistanceMeters(
                            1f
                        )
                        .build()

                fusedLocationClient
                    .requestLocationUpdates(

                        request,

                        object :
                            LocationCallback() {

                            override fun
                                    onLocationResult(
                                result:
                                LocationResult
                            ) {

                                val location =
                                    result
                                        .lastLocation
                                        ?: return

                                riderLat =
                                    location.latitude

                                riderLng =
                                    location.longitude

                                val data = JSONObject()

                                data.put("lat", riderLat)
                                data.put("lng", riderLng)

                                socket.emit("rider_location", data)

                                if (tripStarted) {

                                    if (
                                        previousTripLat != null &&
                                        previousTripLng != null
                                    ) {

                                        val results = FloatArray(1)

                                        Location.distanceBetween(
                                            previousTripLat!!,
                                            previousTripLng!!,
                                            riderLat,
                                            riderLng,
                                            results
                                        )

                                        if (results[0] >= 1f) {

                                            tripDistanceMeters += results[0]

                                        }

                                    }

                                    previousTripLat = riderLat
                                    previousTripLng = riderLng

                                }

                                locationText =
                                    "GPS: " +
                                            riderLat +
                                            ", " +
                                            riderLng
                            }
                        },

                        Looper
                            .getMainLooper()
                    )
            }

            riderMarker.value = Marker(map)
            driverMarker.value = Marker(map)
            roadLine.value = Polyline()

            map
        },

        update = { map ->

            // map.overlays.clear()

            val riderPoint =
                GeoPoint(
                    riderLat,
                    riderLng
                )

            riderMarker.value?.let {

                it.position = riderPoint
                it.title = "You"

                if (!map.overlays.contains(it)) {
                    map.overlays.add(it)
                }

            }

            if (
                driverLat != 0.0
            ) {

                val driverPoint =
                    GeoPoint(
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

                roadLine.value?.let {

                    it.width = 8f

                    it.setPoints(
                        listOf(
                            riderPoint,
                            driverPoint
                        )
                    )

                    if (!map.overlays.contains(it)) {
                        map.overlays.add(it)
                    }

                }

            }

            if (driverLat != 0.0) {

                map.controller.animateTo(
                    GeoPoint(
                        driverLat,
                        driverLng
                    )
                )

            } else {

                map.controller.animateTo(
                    riderPoint
                )

            }


        },

        modifier =
            Modifier
                .fillMaxWidth()
                .fillMaxSize()

    )

    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(12.dp)
    ) {

        if (!rideStatus.startsWith("Trip Completed")) {

            Button(

                onClick = {

                    socket.connect()

                    onRequestRide()
                },

                modifier =
                    Modifier
                        .fillMaxWidth()

            ) {

                Text(
                    "Request Taxi"
                )

            }

            Spacer(
                modifier =
                    Modifier.height(
                        10.dp
                    )
            )

            Text(
                text =
                    rideStatus
            )

            Spacer(
                modifier =
                    Modifier.height(
                        6.dp
                    )
            )

            Text(
                text =
                    locationText
            )

            Spacer(
                modifier =
                    Modifier.height(
                        6.dp
                    )
            )

            Text(
                text =
                    distanceText
            )

            Text(
                text =
                    etaText
            )

            Spacer(
                modifier = Modifier.height(6.dp)
            )

            Text(
                text = "Trip: ${tripDistanceMeters.toInt()} m"
            )

        } else {

            Text(
                text = rideStatus,
                style = MaterialTheme.typography.titleLarge
            )

        }

    }
}