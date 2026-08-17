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
username: your@email.example      # EZVIZ *account* email — the one you log in to the app with
password: your-account-password   # the account password, NOT the camera verification code
region: apiieu.ezvizlife.com      # apiieu = Europe, apius = Americas, apiisgp = Singapore
cameras:
  - serial: BB1234567             # the device serial — see "Finding the serial" below
    port: 8558
log_level: info
```

Up to five cameras, on ports 8558-8562, one port each.

### Finding the serial

The `serial` is the device serial, and it is **not** the six-letter verification code printed on
the camera — that is a different thing and will be rejected. Three ways to get it, easiest first:

1. **Let the add-on tell you.** Fill in `username` and `password`, leave `serial` empty, and
   start the add-on. It will fail — a camera needs a serial — but the log then lists every
   camera on your account with its serial:

   ```
   [ERROR] Cameras on this EZVIZ account -- copy a serial into the configuration:
   [ERROR]   BB1234567  Front door [CS-CP4-R100-6E2WPFBS]
   ```

   Copy the serial into the configuration and start it again. (This works from a stored token
   too, so it still helps on two-factor accounts once you have placed the token.)
2. **In the EZVIZ app:** open the camera, *Settings → Device Information*; the serial is listed
   there, usually 9 characters.
3. **On the device label:** the serial is printed near the QR code, on the body or in the
   manual — distinct from the verification code beside it.

## Using it from go2rtc and Frigate

**Map the port first.** Open the add-on's *Network* tab, set the host port for `8558/tcp` to
`8558`, Save, then fully **Stop and Start** the add-on (not Restart — a port change only takes
effect when the container is recreated). The stream is then reachable at
`http://<home-assistant-ip>:8558/BB1234567.ts`.

Do **not** use an add-on hostname like `local-ezviz_stream_bridge` — it does not resolve from a
store-installed add-on's container, and go2rtc fails with "no such host". Use the Home Assistant
host IP, which the Frigate add-on already knows (it logs `Got IP address from supervisor: …`).

go2rtc, in Frigate's configuration:

```yaml
go2rtc:
  streams:
    doorbell:
      # The ffmpeg: prefix is required — the source is MPEG-TS and go2rtc must demux it.
      # #video=h264 transcodes the camera's HEVC to H.264 so the browser live view shows a
      # picture (HEVC over WebRTC/MSE is usually a black screen). It costs CPU; drop it if you
      # only run detection and never open the live view.
      - "ffmpeg:http://<home-assistant-ip>:8558/BB1234567.ts#video=h264#audio=aac"
```

### Battery cameras: do not give Frigate a permanent role

This is the setting that decides whether the camera lasts months or days. **Every consumer that
stays connected keeps a cloud session open and the camera encoding**, and the add-on faithfully
serves whoever connects — it never generates traffic on its own. So a Frigate input with a
`record` role, or `detect` left enabled, is a 24/7 consumer that never lets the camera sleep.

For a battery doorbell, give the input **no always-on role**, and switch detection on only for
the length of an event, driven by the camera's own motion sensor:

```yaml
cameras:
  doorbell:
    ffmpeg:
      inputs:
        - path: rtsp://127.0.0.1:8554/doorbell
          roles: [detect]
    detect:
      enabled: false     # turned on via MQTT frigate/doorbell/detect/set on a motion event
    record:
      enabled: false     # turned on via MQTT frigate/doorbell/recordings/set, if you want a clip
```

An automation flips `detect`/`record` ON when `binary_sensor.<doorbell>_motion` fires and OFF a
minute later. Note the numbers, measured through the add-on: ~4 s to the first byte, first
keyframe ~1.5 s in, keyframes every 4 s — so an event-gated recording starts mid-scene, six-odd
seconds after the trigger. That is a hardware limit, not a setting.

### Seeing who is connected

The add-on logs every HTTP connection with an id, its source address and User-Agent, and the
VTM session that opens and closes with it:

```
[HTTP] conn=7 connected from=172.30.32.1:41682 ua=Lavf/62.3.100 active=1
[VTM]  conn=7 session opening
[VTM]  conn=7 session closed
[HTTP] conn=7 closed after 63.0s reason='client disconnected' active=1
```

`active` is how many streams are live right now. If it never drops to 0 while nobody is watching,
a consumer still has a permanent role — the source address and `Lavf/…` User-Agent (FFmpeg,
i.e. go2rtc) tell you which one. With everything event-gated, `active` should sit at 0 between
events.

## Credits

The whole EZVIZ protocol implementation is
[pyezvizapi](https://github.com/RenierM26/pyEzvizApi) by RenierM26 — the reverse engineering
of the cloud API, the stream framing and the remux all live there. This add-on only keeps a
session alive and a proxy running per camera.

Source: [Stinocon/ezviz-stream-bridge](https://github.com/Stinocon/ezviz-stream-bridge).
