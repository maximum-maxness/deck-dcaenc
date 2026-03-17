# Debug Session Summary - PipeWire Audio System Issues

## Problem Statement
After running `./install.sh`, the PipeWire audio system failed to start with the error:
```
Could not connect to PipeWire
[ERROR] DTS sink was not found after restarting PipeWire.
```

## Root Causes Identified & Fixed

### Issue #1: Device Number Mapping Bug 🔴
**Severity**: Critical - Causes PipeWire to crash on startup

**What Happened:**
- User selected HDMI output 2 (DELL S2725QS monitor)
- `aplay -l` shows this as device 8
- Script incorrectly mapped this directly to ALSA `DEV=8`
- Correct mapping should be `DEV=2` (HDMI 2 → DEV 2)

**Error Log Evidence:**
```
spa.alsa: 'dcahdmi:CARD=Generic,DEV=8': playback open failed: No such file or directory
pw.conf: can't create object from factory adapter: Invalid argument
```

**Fix Applied:**
- Updated `lib/detect_outputs.sh` to correctly map HDMI numbers to ALSA DEV parameters
- Now tracks HDMI number (0-3) instead of aplay device number
- Returns correct ALSA device identifier

File: [lib/detect_outputs.sh](lib/detect_outputs.sh#L1-L65)

### Issue #2: Stale PipeWire Lock Files 🔴
**Severity**: Critical - Prevents recovery after first failure

**What Happened:**
1. PipeWire crashed due to bad config (Issue #1)
2. Lock file `/run/user/1000/pipewire-0.lock` remained locked
3. PipeWire restart attempts failed with:
   ```
   unable to lock lockfile '/run/user/1000/pipewire-0.lock': 
   Resource temporarily unavailable (maybe another daemon is running)
   ```
4. Multiple restart failures hit systemd restart limit

**Fix Applied:**
- Updated `lib/pipewire.sh` to clear lock files before restart
- `restart_audio_stack()` now removes stale lock files automatically
- Prevents cascading restart failures

File: [lib/pipewire.sh](lib/pipewire.sh#L1-L10)

## Scripts Debugged & Updated

| File | Issue | Fix |
|------|-------|-----|
| `lib/detect_outputs.sh` | Wrong device mapping | Map HDMI numbers correctly, not aplay device numbers |
| `lib/pipewire.sh` | Stale lock files | Auto-clear locks before restart |
| `lib/write_configs.sh` | Wrong device in config | Uses corrected mapping from detect_outputs.sh |
| `install.sh` | Debug output missing | Added proper debug trace redirection |
| `uninstall.sh` | Debug support missing | Added debug flag handling |
| `test-imports.sh` | Debug support missing | Added debug flag handling |

## New Tools Created

### 1. `recover-pipewire.sh` - Comprehensive Recovery Tool
Handles complete PipeWire recovery in stages:
- Kills stalled processes
- Clears lock files
- Resets systemd state
- Starts services individually with verification
- Tests PipeWire connectivity
- Checks for DTS sink

Usage:
```bash
./recover-pipewire.sh
```

### 2. `diagnose-pipewire.sh` - Diagnostic Tool
Tests if PipeWire works without DTS config:
- Disables DTS adapter config temporarily
- Attempts PipeWire startup
- Provides troubleshooting recommendations

Usage:
```bash
./diagnose-pipewire.sh
```

### 3. `BUGFIX_REPORT.md` - Detailed Technical Documentation
Complete reference for:
- Root cause analysis
- Configuration examples (before/after)
- Manual recovery procedures
- Testing procedures
- Device mapping tables

## Logging Improvements

All main scripts now support:

### Logging to File (New)
All output goes to: `steamdeck-dts-live.log`
- Terminal: Clean, readable user-facing output
- Log file: Complete capture for troubleshooting

### Debug Tracing (Enhanced)
Flag: `--debug` or `DEBUG=1`
- Terminal: No trace output (stays clean)
- Log file: Full bash trace (set -x) showing every command executed

Example:
```bash
./install.sh --debug -v     # Detailed troubleshooting
```

## Testing Checklist

After these fixes, normal flow should be:

```bash
# Run fixed installer
./install.sh

# Watch for correct device mapping:
# "Selected: DELL S2725QS (ALSA DEV=2)"  ✓

# Check PipeWire recovery:
# "DTS Live Sink found!"  ✓

# Verify in one terminal:
wpctl status | grep "DTS Live Sink"

# Should show:
# N. DTS Live Sink [vol: 1.00]  ✓

# Test audio:
speaker-test -D default -c 6 -r 48000 -F S16_LE  ✓
```

## Key Learning Points

1. **Device Numbering Mismatch**: ALSA device parameters don't always match `aplay -l` device numbers - must extract actual HDMI number
2. **Lock File Management**: PipeWire lock files can become stale if processes crash prematurely  
3. **Configuration Validation**: Config errors can cascade into systemd restart limits
4. **Debug Output Separation**: Debug traces belong in log files, not terminal (keeps UX clean)
5. **Staged Recovery**: Better to restart services individually with verification between stages

## Files Modified

### Core Fixes
- [lib/detect_outputs.sh](lib/detect_outputs.sh) - Device mapping logic
- [lib/pipewire.sh](lib/pipewire.sh) - Lock file cleanup
- [lib/write_configs.sh](lib/write_configs.sh) - Config generation
- [install.sh](install.sh) - Debug trace handling
- [uninstall.sh](uninstall.sh) - Debug support
- [test-imports.sh](test-imports.sh) - Debug support

### New Recovery Tools
- [recover-pipewire.sh](recover-pipewire.sh) - Recovery orchestration
- [diagnose-pipewire.sh](diagnose-pipewire.sh) - Diagnostic testing

### Documentation
- [BUGFIX_REPORT.md](BUGFIX_REPORT.md) - Technical reference
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Updated with recovery commands
- [README.md](README.md) - Troubleshooting section updated

## Next Steps

1. ✅ Fixes applied to all scripts
2. ✅ Recovery tools created
3. ✅ Debug features enhanced
4. ⏳ **USER**: Test with `./install.sh --reconfigure`
5. ⏳ **USER**: Verify DTS sink appears
6. ⏳ **USER**: Test audio playback
7. ⏳ **USER**: Validate in a game

## Support Resources

- **Quick Recovery**: `./recover-pipewire.sh`
- **Technical Details**: [BUGFIX_REPORT.md](BUGFIX_REPORT.md)
- **Commands Reference**: [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- **Full Troubleshooting**: [README.md](README.md#troubleshooting)
