# nock

A native macOS Dynamic Island player for Apple Music, Spotify, and anything else that’s playing.

Hover the camera housing to expand a now-playing island. A matching menu bar player and mini player share the same engine.

## Requirements

- macOS 14 Sonoma or later
- Apple Music and/or Spotify (Automation permission on first control)
- Optional: a Spotify Developer Client ID for likes

## Build

Xcode is not required. Command Line Tools plus Swift 6 are enough:

```sh
make adapter   # once — builds the MediaRemote helper for system-wide Now Playing
make app
open build/Nock.app
make test      # needs Xcode.app for the test frameworks; adds live checks when Spotify is open
```

The island sits in the hardware notch on notched MacBooks. On other displays it becomes a floating top-center capsule.

## Spotify likes

1. Create an app at [developer.spotify.com](https://developer.spotify.com/dashboard)
2. Set the redirect URI to `http://127.0.0.1:53821/callback`
3. Paste the Client ID in Nock → Settings → Spotify and connect

## Gestures

- Hover the notch to expand
- Click to pin
- Two-finger swipe left/right to skip
- Two-finger swipe down/up to open or close
- Scroll to change volume
