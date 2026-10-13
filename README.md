# OpenMANET packages feed
This is the OpenMANET OpenWrt "packages"-feed containing community-maintained build scripts, options and patches for applications, modules and libraries used within OpenWrt.

Installation of pre-built packages is handled directly by the opkg utility within your running OpenWrt system or by using the OpenWrt SDK on a build system.

Usage
This repository is intended to be layered on-top of an OpenWrt buildroot. If you do not have an OpenWrt buildroot installed, see the documentation at: OpenWrt Buildroot – Installation on the OpenWrt support site.

This feed is enabled by default. To install all its package definitions, run:

./scripts/feeds update
./scripts/feeds install -a -p openmanet

## Aircraft receivers: 1090 MHz ADS-B and 978 MHz UAT

Two packages decode aircraft, each on its own RTL-SDR receiver:

| Band | Package | Decoder | Receiver serial | Output |
|------|---------|---------|-----------------|--------|
| 1090 MHz ADS-B / Mode S | `adsbtocot` (pulls in `dump1090`) | dump1090 | `1090` | `/var/run/dump1090/aircraft.json`, CoT via adsbcot |
| 978 MHz UAT (US) | `dump978-fa` (pulls in `libsoapysdr`, `soapy-rtlsdr`) | dump978-fa + skyaware978 | `978` | raw frames on `127.0.0.1:30978`, `/var/run/skyaware978/aircraft.json` |

### Receiver ownership

Each service opens its receiver by USB serial number, never by index, so
plugging receivers into different ports, or adding scanner receivers, cannot
make a service take the wrong one:

- dump1090: `uci get dump1090.main.device_index` is `1090`. dump1090 reads
  this as a serial. It would read it as an index only if 1090 or more
  receivers were attached.
- dump978-fa: `uci get dump978-fa.main.serial` is `978`. SoapySDR matches it
  exactly. The service refuses to start with an empty serial instead of
  falling back to the first receiver it finds.

An RTL-SDR can be opened by one program at a time, so a running decoder
holds its receiver. Scanner software must also select its receivers by
serial and must never use `1090` or `978`. When serial `1090` is missing,
dump1090 falls back to a serial that starts or ends with `1090`, so do not
give other receivers serials such as `10901`. Avoid the serials `1` to `9`:
dump1090 reads those as indexes.

Stock receivers usually all ship with serial `00000001`. Set the serial once
per receiver with `rtl_eeprom -s` (bench steps 3 to 9).

### Bench steps

Run these on the node, one command per step, when the receivers arrive.
Plug receivers in only as each step says.

1. Install the decoders and the RTL-SDR tools:
   `opkg update && opkg install adsbtocot dump978-fa soapysdr-util rtl-sdr`
2. Confirm that no kernel DVB driver holds the receivers (no output means OK):
   `lsmod | grep -E 'dvb_usb_rtl28xxu|rtl2832'`
3. Plug in **only** the receiver for 1090 MHz, then show its current serial:
   `rtl_eeprom -d 0`
4. Write serial `1090`, answering `y` at the prompt:
   `rtl_eeprom -d 0 -s 1090`
5. Unplug that receiver and plug in **only** the receiver for 978 MHz, then
   write serial `978`, answering `y`:
   `rtl_eeprom -d 0 -s 978`
6. Unplug it, then plug both receivers in (replugging loads the new serials).
   Check that both are listed (`SN: 1090` and `SN: 978`):
   `rtl_test -t`
7. Check that SoapySDR sees the 978 receiver (`serial=978`):
   `SoapySDRUtil --find="driver=rtlsdr"`
8. Check that dump1090 is bound to serial `1090`:
   `uci get dump1090.main.device_index`
9. Enable dump1090 at boot:
   `/etc/init.d/dump1090 enable`
10. Start dump1090:
    `/etc/init.d/dump1090 start`
11. Check that dump1090 holds the 1090 receiver. This must fail with
    `usb_claim_interface error -6`:
    `rtl_test -d 1090 -t`
12. Check that dump1090 left the 978 receiver free. This must open the
    device and print its tuner:
    `rtl_test -d 978 -t`
13. Enable the 978 service in UCI:
    `uci set dump978-fa.main.enabled=1`
14. Save the change:
    `uci commit dump978-fa`
15. Enable dump978-fa at boot:
    `/etc/init.d/dump978-fa enable`
16. Start dump978-fa and skyaware978:
    `/etc/init.d/dump978-fa start`
17. Check that dump978-fa opened its receiver: a `SoapySDR: using ... gain`
    line and no `No matching SoapySDR device`:
    `logread -e dump978-fa`
18. Check that dump978-fa now holds the 978 receiver. This must fail with
    `usb_claim_interface error -6`:
    `rtl_test -d 978 -t`
19. Check the 978 output. The `messages` counter grows while UAT aircraft or
    US ground-station uplinks (FIS-B) are in range:
    `cat /var/run/skyaware978/aircraft.json`
20. Check the 1090 output:
    `cat /var/run/dump1090/aircraft.json`
21. Ownership after re-enumeration: swap the two receivers between USB ports,
    reboot, then repeat steps 11, 17 and 18:
    `reboot`
22. Missing-receiver behaviour: unplug the 978 receiver. dump978-fa should log
    `No matching SoapySDR device` about every 30 s, and step 11 must still
    show the 1090 receiver held by dump1090:
    `logread -f -e dump978-fa`
23. Record decoder CPU use for the qualification report:
    `top -b -n 1 | grep -E 'dump1090|dump978-fa|skyaware978'`

Gain defaults: dump1090 uses `49.6` dB (set by adsbtocot). dump978-fa uses
the receiver's maximum manual gain. To change it, set
`dump978-fa.main.gain` to a number in dB, or to `auto` for tuner AGC, then
commit and run `/etc/init.d/dump978-fa restart`.
