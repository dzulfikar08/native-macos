# Phase 4: Window Recording - Manual Testing Checklist

## Window Selection
- [ ] Window list displays all open applications
  - **Expected:** See windows from Safari, Finder, Notes, etc. (not menu bar/dock)
- [ ] Windows are filtered correctly (no menu bar, dock, or tiny windows)
  - **Expected:** No windows smaller than 100x100, no system UI windows
- [ ] Thumbnails appear after 2 seconds
  - **Expected:** Each window shows 160x120 preview screenshot
- [ ] Can select up to 4 windows with checkboxes
  - **Expected:** Checkboxes enable selection, max 4 checked
- [ ] 5th window selection is rejected
  - **Expected:** 5th checkbox automatically unchecks
- [ ] Window names and app names are displayed correctly
  - **Expected:** Format: "Window Name (App Name)"

## Recording - Single Window
- [ ] Start recording single window
  - **Expected:** Recording starts, mini-view appears
- [ ] Move window during recording (should track correctly)
  - **Expected:** Video shows window at new positions
- [ ] Resize window during recording (should track correctly)
  - **Expected:** Video shows window at new sizes
- [ ] Stop recording produces valid video file
  - **Expected:** .mov file created in Recordings, plays in QuickTime
- [ ] Video contains only the selected window content
  - **Expected:** No other windows or desktop visible in output
- [ ] Audio is captured if enabled
  - **Expected:** System audio and/or mic audio in output

## Recording - Multiple Windows
- [ ] Select and record 2 windows
  - **Expected:** Output shows side-by-side layout (75%/25%)
- [ ] Select and record 3 windows
  - **Expected:** Output shows triple layout (main + 2 smaller)
- [ ] Select and record 4 windows
  - **Expected:** Output shows quad grid layout
- [ ] Layout mode updates automatically (dual, triple, quad)
  - **Expected:** Compositing mode matches window count
- [ ] Output shows both windows in layout
  - **Expected:** Both windows visible and correctly positioned

## State Changes
- [ ] Minimize window during recording → Recording pauses
  - **Expected:** Pause notification appears, capture freezes
- [ ] Restore minimized window → Recording resumes
  - **Expected:** Notification dismissed, capture continues
- [ ] Close window during recording → Recording stops and saves
  - **Expected:** Recording stops gracefully, file saved
- [ ] Switch to different Space → Recording pauses
  - **Expected:** "Window moved to another desktop" message
- [ ] Switch back → Recording resumes
  - **Expected:** Recording continues seamlessly

## Quality Settings
- [ ] Low quality preset works
- [ ] Medium quality preset works
- [ ] High quality preset works
- [ ] Frame rates are correct (24, 30, 60 fps)

## Codecs
- [ ] H.264 codec produces valid video
- [ ] HEVC codec produces valid video (if supported)
- [ ] ProRes codec produces valid video (if supported)

## Edge Cases
- [ ] Record transparent window (transparency preserved)
- [ ] Record fullscreen app
- [ ] Record window on different display
- [ ] Start with no windows available (shows empty state)
- [ ] Permission denied shows alert with System Settings link

## Performance
- [ ] Recording maintains 30fps on typical hardware
- [ ] Memory usage is reasonable
- [ ] CPU usage is acceptable
- [ ] No frame drops during normal recording
