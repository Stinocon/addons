# Changelog

## 0.1.9

- **What a discarded RTP payload type carried is now reported, not only counted.** One RTP
  session can carry more than one payload type — a `CS-C8c` sends its metadata next to its video
  — and the count of the packets skipped says how much was discarded and nothing about what it
  was, because a second media stream and more of the camera's own metadata are the same number.
  A session that carried a second type now logs, per type, how many packets it saw, how many of
  them carried media at all, and the size range of those payloads. It is the difference between a
  stream that is mute because the camera sent nothing and one that is mute because part of what
  it sent was dropped on the floor.
- **With `log_ffmpeg_stderr: true`, the diagnosis names the codec.** The first bytes of each
  payload type's first media packet are printed, and the RTP header line now carries the SSRC:
  two payload types can share one synchronisation source and still number their packets
  separately, which is what a second sender on one RTP session looks like. Up to six payload
  types are printed, with a count of any beyond that.
- Nothing about the forwarded stream changes. The payload type the codec was named from is still
  the only one depacketized, an MPEG-PS session is untouched, and the new lines appear only for a
  session that carried a second payload type.

## 0.1.8

- **A camera that sends its video as RTP now works.** Not every device on this cloud relay sends
  MPEG-PS. A `CS-C8c` sends RTP carrying RFC 6184 H.264 — SPS, PPS and a fragmented IDR split
  across FU-A packets — and FFmpeg's `mpeg` demuxer produces nothing from it: `could not find
  codec parameters`, `bytes=0` in the connection log, on a stream that was arriving perfectly
  intact. Every session now reads its leading video packets, classifies the transport from them,
  and when the payload is RTP depacketizes it into an Annex-B elementary stream (single NAL
  units, STAP-A and AP aggregates, FU-A and FU fragments, RFC 6184 H.264 and RFC 7798 HEVC)
  before starting FFmpeg with the codec as its input format and `-use_wallclock_as_timestamps`,
  without which the MPEG-TS muxer refuses a stream whose container carries no timestamp.
  Verified end to end against the ffmpeg this image installs, for both codecs. An MPEG-PS
  stream — the case that already worked — is unchanged, byte for byte. The price is up to eight
  packets of added latency on every session, because the decision has to be made before FFmpeg
  exists.
- **A stream that produces nothing now says why.** A payload that is RTP with no H.264 or HEVC
  parameter set to name its codec is logged as such and left on the demuxer it has always used,
  rather than refused on a transport the bridge may simply have read wrong; and the packets the
  depacketizer could not read are counted and reported when the session ends. A bare `bytes=0`
  with nothing to act on was the failure this whole line of work started from.
- The `log_ffmpeg_stderr` diagnostic prints the same leading packets as in 0.1.7. Its transport
  line is now the reading the demuxer is chosen from, not only a diagnosis.

## 0.1.7

- **The diagnostic prints the leading packets, not just their first 24 bytes.** With
  `log_ffmpeg_stderr: true`, a payload whose transport is anything other than MPEG-PS (RTP,
  MPEG-TS or unknown) is now printed packet by packet for the first eight packets of the
  session — or all of them, if the session ends first: the length, the decoded RTP header
  fields, the leading 64 bytes, and the payload sliced out at the offset `pyezvizapi`'s own
  unwrap computes. The 24-byte head could not answer the question the flag exists to answer —
  where the video starts and which codec it is — because an RTP header alone is 12 bytes plus up
  to 60 bytes of CSRC list plus a variable-length extension: a camera reported as `transport=RTP`
  with the extension bit set puts its media 40 bytes past the end of what the line printed.
- An MPEG-PS stream, the working case, is unchanged: no packet dump, no retained bytes, and
  nothing different is written to FFmpeg. The flag stays off by default.

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
