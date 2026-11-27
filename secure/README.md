# A12E Secure Boot v2 + Flash Encryption (pilot)

Branch: `feature/secure-boot-a12e`. `main` is untouched.

This is a **provisioning pilot**, not a production release. Do not burn
eFuses on a customer board.

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

The build signs the bootloader and app but does **not** enable Secure Boot on
the chip. Enforcement starts only when the public-key digest is burned.

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
2. Flash it over USB in development mode.
3. Verify boot, Wi-Fi AP, web UI, RS232 weight and activation.
4. Burn the secure-boot public-key digest.
5. Generate and burn the unique flash-encryption key.
6. Enable release-mode flash encryption.
7. Reboot and verify signed boot + encrypted flash.
8. Disable UART download/JTAG via eFuse.
9. Run OTA with a signed image.
10. Record MAC, key ID and test result.

Do not jump to step 4 until steps 1–3 pass on the spare board. Steps 4–8 are
irreversible.

## 6. Safety rules

- Test on a spare A12E board only.
- Never burn eFuses on the production unit first.
- Back up the signing key offline; losing it means no future updates.
- The private key is in `secure/keys/` and is gitignored. Do not commit it.
- Keep a signed recovery image.
- Keep flash encryption in **development mode** until signed OTA has been
  proven. Release mode makes recovery much harder.
- A mistake can permanently brick the board.

## 7. Next step

Connect a spare board and capture:

```text
espefuse.py summary
```

Share the chip revision and eFuse summary. If the board is ECO V3+, continue
with the provisioning test. If it is older, Secure Boot v2 is not available
and the board cannot be used for this pilot.
