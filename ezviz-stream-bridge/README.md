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

## Two settings to change in the EZVIZ app first

Neither is optional, and both fail in ways that do not name themselves.

**1. Turn off two-step verification on the EZVIZ account.** An add-on cannot type a code in, so
a login that asks for one cannot complete. This is not a limitation of this add-on: Home
Assistant's own EZVIZ integration states the same requirement, and adds that Google, Facebook,
TikTok and other OAuth-based accounts do not work either.

If you would rather keep it on, there is one way round it: log in by hand once, and copy the
resulting token file into the add-on's `/data` as the log explains. The add-on renews a working
session on its own; it only needs a human for the first one.

**2. Turn off video encryption for the camera** (*Settings → Image/Video Encryption* in the
app). With it on, the video arrives encrypted, and decrypting it needs the camera's media key,
which the cloud only hands to a **rights-elevated** session — asking for it returns
`resultCode 20002` and sends a verification code to your email. That is the same wall as the
first setting: nobody is there to read the mail.

Unlike the official integration, this add-on does **not** need the camera's six-letter
verification code at all. Do not put it in the password field.

## Battery cameras, and whether Frigate's detect and record can be used

They can — but not by simply leaving them on, and the reason is worth understanding rather than
taking on trust.

Frigate's `detect` is an always-on puller: it holds the stream open for as long as it is
enabled. Every connection to this add-on opens a cloud session and makes the camera encode and
upload, so an always-on consumer means an always-encoding camera. On a 4600 mAh doorbell that
is roughly **hours of battery, not months** — the standby figure on the box assumes the radio
is asleep almost all the time.

So do not leave `detect` on permanently. But you can switch it on for the moment that matters,
which is what you actually want:

1. The doorbell or PIR event arrives in Home Assistant through the EZVIZ integration.
2. An automation publishes `ON` to `frigate/<camera>/detect/set`, and to
   `frigate/<camera>/recordings/set` if you want the clip.
3. After a minute or so, the same automation publishes `OFF`.

Two measured numbers to set expectations, taken through this add-on on a CP4:

- **~4.3 s to the first byte**, and the first keyframe 1.4 s into the stream: call it **six
  seconds from the request to a decodable frame.** Whoever rang is still there, but the
  approach that triggered the event is already over. Event-gated recording on this hardware
  starts mid-scene; it cannot start before.
- **Keyframes every 4 s**, so Frigate's clips are cut on a 4-second grid.

There is no substream: detection runs on the full 1728×1080 HEVC feed, which costs more CPU
than the low-resolution `detect` stream Frigate normally expects.

Mains-powered EZVIZ cameras have none of these limits, but they usually do expose RTSP — in
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

## Using it from go2rtc and Frigate

Add-ons on the same Home Assistant instance reach each other by hostname, so nothing needs to
be published:

```yaml
streams:
  doorbell: http://local-ezviz_stream_bridge:8558/BB1234567.ts
```

Then in Frigate, for a battery camera. `detect` and `record` start **off** and are switched on
by an automation for the length of an event, as described above — not left off forever:

```yaml
cameras:
  doorbell:
    ffmpeg:
      inputs:
        - path: rtsp://127.0.0.1:8554/doorbell
          roles: [detect]
    detect:
      enabled: false     # switched on via frigate/doorbell/detect/set
    record:
      enabled: false     # switched on via frigate/doorbell/recordings/set
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
