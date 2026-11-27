# A12E Secure Boot v2 + Flash Encryption (pilot)

Branch: `feature/secure-boot-a12e`. `main` is untouched.

This is a **provisioning pilot**, not a production release. Do not burn
eFuses on a customer board.

> **The first boot of a `CONFIG_SECURE_BOOT` build locks the board.**
>
> On ESP32 the ESP-IDF bootloader burns the public-key digest into eFuse,
> sets `ABS_DONE_1`, and disables JTAG automatically on that first boot.
> There is **no** "signed but not enforced" state. After that boot the chip
> only runs images signed by `secure/keys/secure_boot_signing_key.pem`.
> This cannot be undone.

## 1. Board check

A12E uses a classic ESP32. Secure Boot v2 requires **ESP32 ECO V3 or newer**.
Older ESP32 revisions only support the deprecated Secure Boot v1.

On a spare board:

```powershell
espefuse.py summary
esptool.py chip_id
```

Confirm the chip revision is ECO V3 or later before going further.

## 2. Build strategy

The current A12E firmware is PlatformIO + Arduino. Secure Boot and Flash
Encryption are ESP-IDF provisioning features, so production builds must use
ESP-IDF.

This branch keeps the existing Arduino source and builds it with **ESP-IDF +
Arduino as a component**. The application code in `src/` is not forked.

| Path | Purpose |
|---|---|
| `CMakeLists.txt` | ESP-IDF project root |
| `main/CMakeLists.txt` | Builds the existing `src/*.cpp` as the `main` component |
| `partitions.csv` | OTA A/B + `nvs_keys` (4 MB flash); table at `0x10000` because the signed bootloader exceeds the default `0x7000` window |
| `sdkconfig.defaults` | Secure Boot v2, Flash Encryption (development mode), NVS encryption |
| `components/arduino/` | Arduino core clone (gitignored) |
| `secure/keys/` | Signing key (gitignored, back up offline) |
| `secure/scripts/` | Setup, key generation and `idf.py` wrapper |

## 3. First build

```powershell
# once: clone the Arduino core used as an ESP-IDF component
powershell -ExecutionPolicy Bypass -File secure/scripts/setup.ps1

# once: generate the Secure Boot v2 RSA-3072 signing key
powershell -ExecutionPolicy Bypass -File secure/scripts/generate_keys.ps1

# configure and build
powershell -ExecutionPolicy Bypass -File secure/scripts/idf.ps1 set-target esp32
powershell -ExecutionPolicy Bypass -File secure/scripts/idf.ps1 build
```

The build signs the bootloader and app. **The first boot after flashing is the
locking event:** the bootloader burns the public-key digest, sets
`ABS_DONE_1`, and disables JTAG. From then on only signed images boot. UART
download stays enabled unless `CONFIG_SECURE_DISABLE_ROM_DL_MODE` is set.

A "signed but not enforced" build does not exist on ESP32. For a no-burn
validation on a clean board, Secure Boot must be disabled entirely
(`CONFIG_SECURE_BOOT` off); that produces an unsigned image.

Two settings are needed because of the IDF build:

- **Partition table offset `0x10000`** — the signed bootloader is ~44 KB and
  does not fit below the default `0x8000`.
- **mbedTLS PSK cipher suites** — Arduino's `NetworkClientSecure`
  (`WiFiClientSecure`) compiles its SSL client only when PSK modes are on.
  The Sheets upload uses it.

## 4. What gets provisioned per board

| Item | Scope | Notes |
|---|---|---|
| Secure Boot signing key | Product | RSA-3072, keep offline, back up twice |
| Flash encryption key | Per device | Unique, generated/burned during provisioning |
| NVS encryption key | Per device | `nvs_keys`, protected by flash encryption |
| A12E1 license | Per device | Existing ECDSA key, unchanged |

Secure Boot and Flash Encryption **cannot be enabled over OTA**. Each board
needs USB provisioning.

## 5. Provisioning outline

1. Build a signed factory image with ESP-IDF.
2. Flash it over USB. **The first boot burns the digest, sets `ABS_DONE_1`,
   and disables JTAG.**
3. Verify signed boot, Wi-Fi AP, web UI, RS232 weight and activation.
4. Generate and burn the unique flash-encryption key (if used).
5. Enable release-mode flash encryption.
6. Reboot and verify signed boot + encrypted flash.
7. Disable UART download via eFuse, if required.
8. Run OTA with a signed image.
9. Record MAC, key digest and test result.

Do not flash a secure-boot build to a board you are not ready to lock. Steps
2 and later are irreversible.

## 6. Pilot board status (locked)

| Item | Value |
|---|---|
| Board | ESP32-D0WD-V3, rev 3.1, 4 MB |
| MAC | `7c:d5:44:27:e6:00` |
| Secure Boot v2 | burned |
| Public-key digest | `3E7583CB88BF1ADFB340A0A1326ABA80EABFADB089FCC62D2241EB88B498B393` |
| JTAG | disabled |
| UART download | enabled |
| Flash encryption | not enabled (`FLASH_CRYPT_CNT = 0`) |

Boot tests on this board:

- Signed IDF build boots, verifies RSA-PSS, starts the AP at `192.168.4.1`,
  runs the web server, and licensing counts the trial.
- The unsigned stock PlatformIO app was flashed to `0x20000` and rejected:

  ```text
  No signature block magic byte found at signature sector (found 0xff not 0xe7).
  E secure_boot_v2: Secure Boot V2 verification failed.
  W esp_image: image valid, signature bad
  E boot: No bootable app partitions in the partition table
  ```

- The signed build was then re-flashed over UART and booted normally.

### Restoring the normal A12E firmware

The stock PlatformIO image is unsigned, so it will not boot on this board. To
put the normal firmware back it must be signed with the same key:

- sign the bootloader and app with `espsecure.py`, or
- build the Arduino source through this ESP-IDF project with
  `CONFIG_SECURE_BOOT=y`.

UART download is still enabled, so recovery with a signed image always works.

## 7. Safety rules

- Test on a spare A12E board only.
- **Any board flashed with `CONFIG_SECURE_BOOT=y` locks on first boot.** Do not
  flash it to a board you want to keep open.
- Never burn eFuses on the production unit first.
- Back up the signing key offline; losing it means no future updates.
- The private key is in `secure/keys/` and is gitignored. Do not commit it.
- Keep a signed recovery image.
- Keep flash encryption in **development mode** until signed OTA has been
  proven. Release mode makes recovery much harder.
- A mistake can permanently brick the board.

## 8. Next step

The pilot board is already Secure Boot locked. The remaining decisions are:

1. Test a signed OTA update to `ota_1`.
2. Decide whether to enable flash encryption on this board (permanent) or keep
   it off.
3. Use a different board for any unsigned/stock firmware testing.
