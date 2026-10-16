# Toteel Sudan iOS starter projects

These are new, separate native SwiftUI projects for the existing Sudan service. They do not replace or edit the Android projects and they do not change the VPS.

## Project folders

- `ios/ToteelRider` — Rider app, bundle ID `com.toteel.ios.rider`
- `ios/ToteelDriver` — Driver app, bundle ID `com.toteel.ios.driver`
- `codemagic.yaml` — hosted macOS/Xcode compile workflows

The Xcode project files are generated in Codemagic by XcodeGen from each `project.yml`. This avoids needing Xcode on Windows.

## Existing Sudan protocol implemented

- Server: `http://46.4.202.163:3001`
- Socket.IO authentication: `auth_login`, `auth_register` (Rider only), `auth_logged_in`, `auth_registered`, `auth_verify`
- Socket identity registration: `register`
- Ride events: `set_pickup`, `set_destination`, `request_ride`, `new_ride_request`, `driver_offer`, `new_offer`, `accept_offer`, `ride_accepted`
- Trip events: `driver_arrived`, `start_trip`, `complete_trip`, `cancel_trip`
- Private chat: `chat_message` with `offerId`; incoming messages are only added to the current matching chat when one is selected
- Driver location: `driver_location`

Driver accounts must already be created by Toteel administration. The Driver login field accepts the existing four-character driver code and sends it as the server's `password` field. Rider registration is available inside the Rider app.

## How to use on Windows

1. Extract this archive into `C:\Users\user\AndroidStudioProjects\TOTEEL`, merging the new `ios` folder and adding the root `codemagic.yaml` only if you do not already have a file with that name.
2. Keep the existing Android folders as they are. The project does not ask you to open or rebuild Android Studio projects.
3. Open Codemagic in your browser and connect the GitHub repository `samisuliman3/TOTEEL` (use the exact repository shown in your account). Select the branch containing these files and allow Codemagic to read `codemagic.yaml`.
4. Run `toteel-rider-ios-unsigned` and `toteel-driver-ios-unsigned` separately. These are compile checks, not installable iPhone packages.

If `codemagic.yaml` already exists in the repository, do not overwrite it blindly; merge the two `workflows` entries from this file into the existing YAML instead. YAML indentation matters.

## Important limitations before iPhone installation or release

- The included workflows intentionally build **unsigned** app bundles so we can catch source/build errors first. An unsigned `.app` cannot be installed directly on a physical iPhone. A signed `.ipa` for a real iPhone or TestFlight requires Apple Developer signing credentials and provisioning; Codemagic can do the cloud build without your own Mac once signing is configured.
- The existing Sudan endpoint is plain HTTP by IP address. The starter enables arbitrary HTTP loads only to allow development connectivity to that current endpoint. This is not a production-ready security configuration. Before a public iOS release, put the Sudan service behind HTTPS with a proper domain and remove the broad App Transport Security exception.
- Foreground chat messages are handled via the existing Socket.IO connection. Background push alerts require Apple Push Notification service (APNs) configuration and server-side push delivery; that is not included here.
- The live backend still uses a single global `currentTrip` state. This iOS project does not fix that server-side multi-driver limitation.
- The app sources are a first starter implementation and have not been compiled with Xcode in this environment. Use the Codemagic build logs to resolve any platform-specific compile issues before installing/testing on a phone.

## Security

Do not commit `sudan.env`, admin passwords, user passwords, signing certificates, provisioning profiles, or API/private keys to GitHub. The repository was described as public, so treat all committed content as publicly readable.
