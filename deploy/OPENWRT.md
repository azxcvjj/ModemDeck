# OpenWrt / iStoreOS experimental deployment

This is an opt-in hardware-discovery adaptation, not a claim of working QDC507 voice media.
The standard deployment and udev readiness checks remain unchanged.

## Why two changes are required

The device owner can explicitly use `--discovery-backend sysfs` (entrypoint environment:
`MODEMDECK_DISCOVERY_BACKEND=sysfs`, advanced mode only). It checks live sysfs identity,
character device type and matching major/minor numbers rather than requiring host udev
records. The assignment, settling, external process descriptor and host D-Bus guards
remain active. Missing or ambiguous devices and unavailable ownership visibility fail
closed. No udev database is fabricated and no host service is stopped by the stack.

The hardware image also needs ModemManager built with `-Dudev=false` and
`-Dudevdir=/usr/lib/udev`. A libudev build can accept reported events without discovering
any modems on OpenWrt. The generic sysfs backend uses the supplied kernel events.

## Build

From the repository root:

```sh
docker build -f hardware/Dockerfile.openwrt -t local/modemdeck-hardware:openwrt .
```

The build uses a digest-pinned v1.14.0 base, pinned Debian ModemManager source and a
pinned Go builder. Pass HTTP_PROXY/HTTPS_PROXY build args if needed. It builds the
owner from this checkout; do not copy arbitrary precompiled executables into the image.
Compilation is limited to two jobs. The local build is native to the build machine.

## Prepare an isolated trial

Use the standalone `docker-compose.openwrt.yml`, not the simple installer. Set
MODEMDECK_TRIAL_DIR to a persistent absolute directory. It must contain:

- assignments.json: copy the advanced assignment example and select one exact device.
- media.json: start with hardware/config/media-bindings.empty.json.
- data/tls: writable by UID/GID 10001; data must be owned by 10001:10001.
- settings-key: 32 random bytes readable by the API UID, private to that account.

Set MODEMDECK_BIND_ADDRESS to the intended LAN address (default loopback), and include
it in MODEMDECK_TLS_HOSTS. First browser visit creates the administrator account.
Do not expose an uninitialized installation to the public internet.

The default node mappings are for a single ttyUSB0..3/cdc-wdm0 modem. Verify all nodes
belong to the assigned device. Kernel node renumbering requires updating both sides of
the mappings in Compose; do not map an unrelated source onto a guessed target number.
Stop the existing application that owns the modem before starting the trial and keep
its configuration/data for rollback. Host ModemManager must exclude the assigned modem.
The trial intentionally has no restart policy, Docker socket, privileged mode, raw USB
mapping, host networking or NET_ADMIN. It cannot configure host data routes, automatically
provision USB composition, or access the SIM reader. Host /proc and D-Bus are read-only
visibility mounts; SYS_PTRACE is needed to inspect foreign device owners, not to control them.

```sh
docker compose -f docker-compose.openwrt.yml up -d
# Stop the entire trial before restoring the previous modem owner:
docker compose -f docker-compose.openwrt.yml down
```

## Validation on iStoreOS

On Linux 6.6.144, QDC507 in QMI mode:
- The full ownership unit suite passed, including opt-in/missing-udev tests, stale
  sysfs identity, regular-file and mismatched character-device rejection.
- With VoCat owning the AT port, the runtime rejected ownership before reporting ports.
- After releasing VoCat, sysfs discovery reported only the assigned six ports.
- The no-udev ModemManager created the Quectel modem and registered on China Unicom LTE.
- VoCat was restored after bounded hardware tests; the separate reader Gateway was untouched.

## Limits

This does not yet enable QDC507 audio. ADB/UAC, kernel-specific module runtime and strict
same-device ALSA binding still require separate verification. No USB/NV or firmware changes
are performed by this trial configuration. Real inbound/outbound speech is unverified.
Package upgrades of host modem software may undo locally maintained exclusions; verify
ownership after an upgrade. Keep the standard deployment for udev-based hosts.

The three-service trial was also started successfully on iStoreOS: hardware, API and
Web health checks passed, the readiness API reported all four checks OK, and total
observed idle memory was about 38 MiB. No administrator was created automatically.
The default locally generated certificate requires browser confirmation; certificate
trust and microphone permission were not changed by the deployment.
