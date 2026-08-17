# EZVIZ Stream Bridge

Serves the video from an EZVIZ camera as MPEG-TS over HTTP, so go2rtc, Frigate, or anything
else that speaks FFmpeg can use a camera that offers no RTSP.

## What this is for, and what it is not

Some EZVIZ devices — the video door viewers and several battery models — have no local video
interface whatsoever. Not RTSP disabled, not RTSP hidden behind a setting: never implemented.
EZVIZ's own *Network Open Port List and Usage Specification* lists RTSP and ONVIF for its IP
cameras and omits both for the "Video Door Viewers & Video Doorbells & Video Doorphones"
category. There is no menu to find and no firmware flag to flip.

This add-on is the way to get pictures out of those devices anyway.

**It reaches the camera through the EZVIZ cloud.** That is not a shortcut taken for
convenience, it is the only path these devices offer, and it has a consequence worth
understanding before installing: **with no internet connection, there is no stream.** If what
you want is a doorbell that keeps working when the line is down, no software gets you there —
that needs hardware with a native local interface.

What you do get is your camera in Home Assistant and Frigate, without the EZVIZ app.

## Battery cameras: read this before configuring Frigate

Every HTTP client that connects opens a new cloud session and wakes the camera. A consumer
that stays connected therefore never lets it sleep, and on a battery model that flattens the
battery in days rather than months.

So for battery cameras: **leave Frigate's `detect` and `record` off**, and treat the stream as
on-demand — a live view you open, not a feed that runs. Continuous detection on a 4600 mAh
doorbell is not a configuration to tune, it is a thing the hardware cannot do.

Mains-powered EZVIZ cameras have no such limit, but note that they usually do expose RTSP, in
which case you do not need this add-on at all.

## Configuration

```yaml
username: your@email.example      # EZVIZ *account* credentials, not the camera's
password: your-account-password   # 6-letter verification code
region: apiieu.ezvizlife.com      # apiieu = Europe, apius = Americas, apiisgp = Singapore
cameras:
  - serial: BB1234567             # from the device label / the app's device information
    port: 8558
log_level: info
```

`serial` is the device serial, which is not the six-letter verification code printed on the
camera — that is a different thing and will be rejected. Up to five cameras, on ports
8558-8562, one port each.

Two-factor authentication on the EZVIZ account cannot work here: nothing in an add-on can type
a code in. Either turn it off for this account, or log in once by hand and drop the resulting
token into `/addon_configs`/`/data` as the log explains.

## Using it from go2rtc and Frigate

Add-ons on the same Home Assistant instance reach each other by hostname, so nothing needs to
be published:

```yaml
streams:
  doorbell: http://local-ezviz_stream_bridge:8558/BB1234567.ts
```

Then in Frigate, for a battery camera:

```yaml
cameras:
  doorbell:
    ffmpeg:
      inputs:
        - path: rtsp://127.0.0.1:8554/doorbell
          roles: [detect]
    detect:
      enabled: false
    record:
      enabled: false
```

For a Frigate running outside Home Assistant, map the port in the add-on's *Network* tab and
point it at the Home Assistant host instead. Be aware that the stream is not authenticated:
mapping the port publishes it to everyone on the LAN.

## Credits

The whole EZVIZ protocol implementation is
[pyezvizapi](https://github.com/RenierM26/pyEzvizApi) by RenierM26 — the reverse engineering
of the cloud API, the stream framing and the remux all live there. This add-on only keeps a
session alive and a proxy running per camera.

Source: [Stinocon/ezviz-stream-bridge](https://github.com/Stinocon/ezviz-stream-bridge).
