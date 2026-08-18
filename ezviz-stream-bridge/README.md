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

So do not leave the camera enabled in Frigate permanently. But you can switch it on for the
moment that matters, which is what you actually want:

1. The doorbell or PIR event arrives in Home Assistant through the EZVIZ integration.
2. An automation publishes `ON` to `frigate/<camera>/enabled/set`.
3. After a minute or so, the same automation publishes `OFF`.

**Use `enabled`, not `detect`.** Verified against Frigate 0.16–0.18: `detect`, `recordings` and
`snapshots` change what Frigate does with the frames it already has, not whether FFmpeg keeps
pulling them — only `enabled` stops the consumer, and it does not exist before Frigate 0.16.
Note too that go2rtc is a separate process which knows nothing about that flag: any live view
— the Frigate UI, a dashboard card — opens a consumer of its own regardless.

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
serves whoever connects — it never generates traffic on its own. A camera left enabled in
Frigate is exactly that consumer: its FFmpeg pulls the stream continuously for as long as the
camera is enabled, whatever `detect` is set to. A `record` role adds a second one.

For a battery doorbell, give the input a single `detect` role, no `record` role, and switch the
whole camera on only for the length of an event, driven by the camera's own motion sensor:

```yaml
cameras:
  doorbell:
    ffmpeg:
      inputs:
        - path: rtsp://127.0.0.1:8554/doorbell
          roles: [detect]     # no record role: that would be a second permanent consumer
    detect:
      enabled: true           # decides what Frigate does with the frames, not whether it pulls
    record:
      enabled: false
```

Note what is *not* in that snippet: `enabled: false`. Frigate records the camera's configured
value as `enabled_in_config` at start-up and **refuses `enabled/set = ON` over MQTT for a camera
that is disabled in the config** — setting it there would leave the switch permanently dead.
Leave `enabled` at its default and have the automation publish `OFF` once when Home Assistant
starts, which is also what puts the camera back to sleep after a Frigate restart: up to 0.17
Frigate does not remember the runtime state, so a restart brings the camera back enabled.

An automation flips `frigate/doorbell/enabled/set` ON when `binary_sensor.<doorbell>_motion`
fires and OFF a minute later. Note the numbers, measured through the add-on: ~4 s to the first
byte, first keyframe ~1.5 s in, keyframes every 4 s — so an event-gated recording starts
mid-scene, six-odd seconds after the trigger. That is a hardware limit, not a setting.

### Event-gated in practice: two Home Assistant automations

A worked example of the pattern this add-on exists for. **Adapt the entity ids** — every one of
them below is a placeholder, and two of them come from components that name entities after
*your* device and camera names:

| entity | who creates it | notes |
|---|---|---|
| `binary_sensor.ezviz_doorbell_motion` | the **official EZVIZ integration** for Home Assistant | **Not** from Frigate, and not from this add-on. The name follows your EZVIZ device name — find yours under *Developer tools → States* and substitute it |
| `binary_sensor.doorbell_person_occupancy` | Frigate (via the Frigate HA integration) | Named after the **Frigate camera**, here `doorbell` |
| `image.doorbell_person` | Frigate (via the Frigate HA integration) | Same, the last person snapshot |
| `person.user_1`, `notify.mobile_app_user_1` | your Home Assistant | Placeholders for your people and phones |
| `alarm_control_panel.home_alarm` | your alarm, **if you have one** | Entirely optional — see the note under the second automation |

The chain is:

```
EZVIZ integration motion sensor  (the only signal available while the camera sleeps)
   -> MQTT frigate/doorbell/enabled/set = ON
      -> Frigate starts its FFmpeg, go2rtc opens this add-on, the bridge opens one cloud session
         -> detection, tracking and recording, for as long as the camera stays enabled
            -> Frigate's own person detection
               -> a Home Assistant notification with the snapshot
```

Responsibilities stay separated: EZVIZ decides *when there is something to look at*, Frigate does
the looking, Home Assistant does the telling.

**1. The stream lifecycle.**

```yaml
alias: Doorbell - Frigate lifecycle
description: >
  Enables the Frigate camera while the EZVIZ motion sensor reports activity, and disables it
  again 60 seconds after that activity stops. The camera streams only around events.
triggers:
  - trigger: state
    entity_id: binary_sensor.ezviz_doorbell_motion
    to: "on"
  - trigger: state
    entity_id: binary_sensor.ezviz_doorbell_motion
    to: "off"
    for:
      seconds: 60
actions:
  # The current state is read again here rather than trusted from the trigger: with
  # mode: restart a returning motion cancels the pending run, and this keeps the published
  # command consistent with what the sensor actually says at the moment of publishing.
  - choose:
      - conditions:
          - condition: state
            entity_id: binary_sensor.ezviz_doorbell_motion
            state: "on"
        sequence:
          - action: mqtt.publish
            data:
              topic: frigate/doorbell/enabled/set
              payload: "ON"
      - conditions:
          - condition: state
            entity_id: binary_sensor.ezviz_doorbell_motion
            state: "off"
        sequence:
          - action: mqtt.publish
            data:
              topic: frigate/doorbell/enabled/set
              payload: "OFF"
mode: restart
```

`enabled` is the only Frigate switch that stops the stream being consumed — see the section
above. `mode: restart` is deliberate: motion returning inside the 60 seconds cancels the pending
shutdown. Note the triggers carry no `from:` clause on purpose: an entity that goes
`unavailable → on` (an integration hiccup, a cloud error) would otherwise never fire, and a
Home Assistant restart re-arms the off-branch by itself as the sensor settles.

**2. The notification.**

```yaml
alias: Doorbell - person detected
description: Critical notification with a snapshot when Frigate sees a person at the door.
triggers:
  - trigger: state
    entity_id: binary_sensor.doorbell_person_occupancy
    from: "off"
    to: "on"
    for:
      seconds: 3
conditions:
  # OPTIONAL. Delete this whole block to be notified every time. It exists so the phone only
  # buzzes when nobody is home, or when the alarm is armed; `alarm_control_panel.home_alarm`
  # is only an example — plenty of installations have no alarm entity at all.
  - condition: or
    conditions:
      - condition: template
        value_template: >
          {{ states('person.user_1') != 'home' and states('person.user_2') != 'home' }}
      - condition: state
        entity_id: alarm_control_panel.home_alarm
        state:
          - armed_away
          - armed_home
actions:
  - action: notify.mobile_app_user_1
    data:
      title: Someone at the door
      message: A person was detected at the door.
      data:
        image: /api/image_proxy/image.doorbell_person
        push:
          sound:
            name: default
            critical: 1
            volume: 1
  - action: notify.mobile_app_user_2
    data:
      title: Someone at the door
      message: A person was detected at the door.
      data:
        image: /api/image_proxy/image.doorbell_person
        push:
          sound:
            name: default
            critical: 1
            volume: 1
mode: single
```

#### What this buys, and what it costs

The point is the battery: the camera streams for a minute or two per event instead of
permanently. Everything below is the price, stated up front.

- **The notification is 25-60 seconds late, and that is a floor, not a tuning problem.** The
  official EZVIZ integration polls the cloud every 30 s, and its motion sensor is really
  "an alarm arrived within the last 60 s" rather than "motion is happening now". Add Frigate's
  own start-up (its watchdog checks the enabled flag every `ffmpeg.retry_interval`, 10 s by
  default) and the few seconds this add-on needs to open the cloud session and fill FFmpeg's
  probe. **You capture the tail of an event, not its beginning**: whoever rang is still there;
  whoever walked past is already gone.
- **A Frigate restart leaves the camera enabled.** Up to Frigate 0.17 the runtime enabled state
  is not remembered, so a restarted Frigate comes back with the camera enabled and starts
  consuming again. This example does not cover that — the next motion cycle turns it off, which
  may be hours away. If that matters to you, add a third trigger on the MQTT topic
  `frigate/available` with payload `online` and publish `OFF`.
- **`person_occupancy` can be left stale.** If the camera is disabled while a person is still
  tracked — someone standing still stops producing motion long before they leave — Frigate stops
  updating the topic and the sensor keeps its last value until frames flow again. The `off → on`
  edge of the next event can then be missed. A trigger on the MQTT topic `frigate/events`
  filtering `type: new` and `label: person` is immune to this, at the cost of a template.
- **The live view is a separate consumer.** go2rtc is a different process and knows nothing
  about the `enabled` flag, so opening the Frigate live view — or a dashboard card that streams
  — wakes the camera regardless of these automations, for as long as the page is open. That is
  not a fault to compensate for in an automation; it is worth knowing before leaving a tab open.

### Seeing who is connected

The add-on logs every HTTP connection with an id, its source address and User-Agent, and the
VTM session that opens and closes with it:

```
2026-08-18T09:03:04.118+02:00 [INFO] [HTTP] conn=7 connected from=172.30.32.1:41682 ua=Lavf/62.3.100 active=1
2026-08-18T09:03:04.119+02:00 [INFO] [VTM]  conn=7 session opening
2026-08-18T09:03:04.530+02:00 [INFO] [VTM]  conn=7 session opened after=0.412s
2026-08-18T09:03:10.298+02:00 [INFO] [VTM]  conn=7 first-video after=6.180s
2026-08-18T09:03:10.812+02:00 [INFO] [HTTP] conn=7 first-byte after=6.694s
2026-08-18T09:04:13.905+02:00 [INFO] [VTM]  conn=7 session closed
2026-08-18T09:04:13.907+02:00 [INFO] [HTTP] conn=7 closed after=69.789s reason='client disconnected' bytes=41217536 video-packets=3187 active=0
```

`active` is how many streams are live right now. If it never drops to 0 while nobody is watching,
a consumer still has a permanent role — the source address and `Lavf/…` User-Agent (FFmpeg,
i.e. go2rtc) tell you which one. With everything event-gated, `active` should sit at 0 between
events.

The two timings are the ones worth reading. **`first-video`** is when the camera actually started
sending: it measures the wake-up, and its absence means the camera never woke (the session then
closes itself, `reason='no video'`). **`first-byte`** is when the consumer started receiving; the
gap between the two is FFmpeg's probe, not the camera. Both timestamps carry milliseconds and an
explicit UTC offset, so they line up directly with Frigate's, go2rtc's and Home Assistant's logs.

`reason` says how a session ended: `client disconnected` (the consumer went away — noticed within
half a second, even when no video was flowing), `no video` (the camera never woke within the
budget), `stream ended`, `camera timeout` or `error`.

## Credits

The whole EZVIZ protocol implementation is
[pyezvizapi](https://github.com/RenierM26/pyEzvizApi) by RenierM26 — the reverse engineering
of the cloud API, the stream framing and the remux all live there. This add-on only keeps a
session alive and a proxy running per camera.

Source: [Stinocon/ezviz-stream-bridge](https://github.com/Stinocon/ezviz-stream-bridge).
