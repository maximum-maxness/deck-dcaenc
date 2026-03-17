# BUGFIX: PipeWire Device Mapping & Lock File Issues

## What Was Wrong

### Bug #1: Incorrect Device Number Mapping  
**Impact**: PipeWire fails because ALSA device path is wrong  
**Root Cause**: Converting `aplay -l` device numbers directly to ALSA `DEV=N` parameters

- `aplay -l` shows: `device 8: HDMI 2 [DELL S2725QS]`
- Previous code used: `dcahdmi:CARD=Generic,DEV=8` ❌
- Correct mapping: `dcahdmi:CARD=Generic,DEV=2` ✓

**HDMI Number Mapping:**
- HDMI 0 → DEV=0 (even if aplay shows device 3)
- HDMI 1 → DEV=1 (even if aplay shows device 7)
- HDMI 2 → DEV=2 (even if aplay shows device 8)
- HDMI 3 → DEV=3 (even if aplay shows device 9)

**Solution**: Use the HDMI number, not the aplay device number

### Bug #2: Stale PipeWire Lock Files
**Impact**: PipeWire won't start after failed attempts  
**Error**: `unable to lock lockfile '/run/user/1000/pipewire-0.lock'`

**Solution**: Clear lock files before restarting

```bash
rm -f /run/user/1000/pipewire-*.lock
rm -f /run/user/1000/pipewire-*.state
rm -f /run/user/1000/pipewire-0-manager
```

## Fixes Applied

### 1. **Fixed detect_outputs.sh**
- Now correctly maps aplay HDMI number to ALSA DEV parameter
- Stores HDMI number (0-3) instead of aplay device number
- Returns correct ALSA DEV value for configuration

### 2. **Fixed pipewire.sh restart_audio_stack()**
- Auto-clears lock files before restart
- Prevents "already running" lock file errors

### 3. **Fixed write_configs.sh**
- All device references now use the correct DEV mapping

## Manual Recovery

If PipeWire is stuck, run:

```bash
# Kill all audio processes
pkill -9 pipewire pipewire-pulse wireplumber

# Clear lock files
rm -f /run/user/1000/pipewire-*.lock
rm -f /run/user/1000/pipewire-*.state

# Fix systemd state
systemctl --user reset-failed

# Restart
systemctl --user start pipewire.socket
sleep 2
systemctl --user start pipewire

# Verify
wpctl status
```

Or use the recovery script:

```bash
./recover-pipewire.sh
```

## Configuration Examples

### Before (Wrong):
```
api.alsa.path = "dcahdmi:CARD=Generic,DEV=8"  ❌
```

### After (Correct):
```
api.alsa.path = "dcahdmi:CARD=Generic,DEV=2"  ✓
```

## Testing

```bash
# Test with fixed config:
./install.sh --reconfigure

# This will:
# 1. Present HDMI selection menu (0-3 for HDMI 0-3)
# 2. Correctly map selection to ALSA DEV parameter
# 3. Write corrected configuration
# 4. Restart audio with lock file cleanup
# 5. Verify DTS sink appears
 ```

## What Happened During Installation

1. User ran full installation
2. installer correctly detected 4 HDMI outputs
3. User selected option "2" (HDMI 2, DELL S2725QS)
4. Bug caused mapping: HDMI 2 → DEV=8 instead of DEV=2
5. PipeWire adapter config tried to open: `dcahdmi:CARD=Generic,DEV=8`
6. ALSA reported: "No such file or directory"
7. PipeWire crashed during startup
8. Multiple restart attempts created stale lock files
9. Subsequent restarts failed due to lock file

## Prevention

All fixes have been applied to the scripts:
- ✓ Device mapping now correct
- ✓ Lock file cleanup added to restart function
- ✓ Verbose logging shows actual device mapping
- ✓ Error messages clearer and more helpful

## Testing the Fix

Run with corrected code:

```bash
./install.sh --reconfigure --verbose
```

Watch for these messages in the log:
- `Selected: DELL S2725QS (ALSA DEV=2)` ✓
- `Writing PipeWire DTS sink configuration...` ✓
- `Restarting PipeWire audio stack...` ✓
- `Found DTS Live Sink with ID: XX` ✓

Then verify:
```bash
wpctl status | grep "DTS Live Sink"
```

Should show: `N. DTS Live Sink [vol: 1.00]`
