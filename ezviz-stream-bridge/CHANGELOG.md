# Changelog

## 0.1.6

- **The transport sniff no longer misreads a packet boundary as a fault.** The 0.1.5 diagnostic
  classified each of the first video packets on its own first byte. VTM packets are arbitrary
  chunks of the MPEG-PS byte stream, so a packet starting mid-pack handed the check a mid-stream
  byte that read as `RTP` or `UNKNOWN` — which looks like a framing mismatch on a stream that is
  perfectly fine. The sniff now buffers a bounded prefix and scans it for a real signature (the
  MPEG-PS pack start code, the MPEG-TS sync grid), reporting the transport and the offset the
  signature sits at. It logs once, and it no longer depends on where the packet boundaries fell.

## 0.1.5

- **A stream that produces nothing can now be diagnosed, not guessed at.** FFmpeg's stderr was
  discarded, so when a camera sent video packets but no MPEG-TS came out (`bytes=0` in the
  connection log) there was no way to see why. Set `log_ffmpeg_stderr: true` and FFmpeg runs at
  `info` with its stderr logged, bounded to 20 lines and then a single suppression notice — the
  pipe is still drained, so FFmpeg cannot block on a full buffer. The same flag logs the detected
  payload transport (MPEG-PS, MPEG-TS, RTP or unknown) of the first video packets, which tells a
  framing mismatch apart from an encrypted-stream problem. Off by default: nothing changes unless
  it is turned on.

## 0.1.4

- **A camera timeout no longer wakes the camera straight back up.** When a session ended
  because the camera went offline mid-stream, the consumer (FFmpeg through go2rtc) reconnected
  instantly and the bridge served the new GET immediately — waking the camera again seconds
  after it had just fallen asleep. On a battery doorbell that loop is what triples the drain:
  the camera never gets a real sleep. The bridge now arms a cooldown when a session ends with
  `camera timeout`: the next session is withheld for `--timeout-cooldown` (30 s by default, `0`
  disables it) before a VTM session is opened, and the wait ends early if the consumer goes
  away. The deadline is fixed in time, so a reconnect loop cannot wake the camera more often
  than once per cooldown. "No client, no VTM" is unchanged: the cooldown is a pause between
  inbound requests, never a request the bridge originates.
- The closing connection now logs `camera went offline mid-stream; next wake delayed …` when the
  cooldown arms, so the delay can be lined up with Frigate, go2rtc and Home Assistant logs.

## 0.1.3

- **A stream session can no longer outlive the consumer that asked for it.** The bridge used to
  notice a consumer had gone only when it next tried to write to it — and with a battery camera
  asleep there is nothing to write, so a consumer that disconnected left the cloud session open.
  The keepalives holding that orphan open were the bridge's own, sent every 5 s, so it never
  timed out either. Measured on a CP4: a session still alive 155 s after its consumer had gone,
  with the camera kept awake the whole time. The request socket is now watched for a peer close,
  so the session ends within half a second whether or not video is flowing.
- **A camera that never wakes no longer holds a session either.** If no video arrives within
  `--first-video-timeout` (25 s by default, deliberately under go2rtc's hardcoded 30 s), the
  session closes itself. `0` disables the budget and restores the old wait-forever behaviour.
- **`first-video` and `first-byte` are now logged, with timestamps to the millisecond.** Every
  line carries an ISO-8601 local time with its UTC offset, and each session reports when the
  VTM opened, when the camera actually started sending, and when the consumer started receiving
  — so a wake-up can be measured against Frigate, go2rtc and Home Assistant instead of guessed.
  The closing line now also reports the bytes served and the video packets received.
- The connection log format changed accordingly: `closed after=20.700s reason='…' bytes=N
  video-packets=N active=N`. Anything grepping the old `closed after 20.7s` needs updating.
- The configured `log_level` now reaches the proxy. It never had: the second logging setup was
  a no-op, so `debug` behaved exactly like `info`. At `debug` the proxy also logs each
  consumer's request headers.
- **Documentation correction — gate Frigate with `enabled`, not `detect`.** Verified against
  Frigate 0.16–0.18: `detect`, `recordings` and `snapshots` change what Frigate does with the
  frames, not whether FFmpeg keeps pulling them; only `frigate/<camera>/enabled/set` stops the
  consumer. And go2rtc, a separate process, ignores that flag entirely — so any live view opens
  a consumer of its own regardless of it.
- Requires pyezvizapi 1.0.5 or newer.

## 0.1.2

- The proxy now runs in-process instead of shelling out to `pyezvizapi stream proxy`, so every
  HTTP connection is logged with an id, its source address and User-Agent, and the VTM session
  that opens and closes with it. This is what identifies a stuck consumer: if `active` never
  returns to 0 while nobody watches, the source address and `Lavf/…` User-Agent name it.
- The lifecycle is unchanged and confirmed on-demand: one connection opens one VTM session,
  closed the instant the client disconnects; the bridge generates no traffic of its own, and no
  retry or keepalive keeps a session alive without a client.
- Corrected the start-up log and README: the reachable endpoint is the Home Assistant host IP on
  the mapped port, never the `local-ezviz_stream_bridge` hostname (which does not resolve from a
  store add-on and made go2rtc fail with "no such host").
- README: the go2rtc/Frigate section now spells out the permanent-consumer trap for battery
  cameras — a `record` role or enabled `detect` never lets the camera sleep — and how to read
  the new connection logs.

## 0.1.1

- A missing serial now lists the account's cameras in the log, each with its serial and model,
  instead of only rejecting the empty field. Enter the credentials, leave the serial blank,
  start once, and copy the serial the log prints. Works from a stored token too, so it still
  helps on two-factor accounts.
- README: a proper "Finding the serial" section, and a corrected note — the account password is
  not the camera verification code, and the verification code is not needed at all.

## 0.1.0

First release.

Serves EZVIZ camera video as MPEG-TS over HTTP, one port per camera, for go2rtc, Frigate
and anything else that speaks FFmpeg. Built for cameras that expose no RTSP at all — the
video door viewers and battery models, where EZVIZ never implemented it.

- One supervised proxy per camera, restarted with a growing, capped delay.
- The EZVIZ session is established once and kept on `/data`; it is verified before every
  proxy start and renewed when the cloud stops accepting it.
- Accounts with two-factor authentication are reported as such instead of failing in a
  restart loop, with the one-off command that works around it.
- Pinned to `pyezvizapi` 1.0.5.0, with the flags the service relies on checked at build time.
