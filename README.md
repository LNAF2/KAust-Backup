# KAust - Karaoke App

## Setup Instructions for Fresh Clone

To ensure the app works exactly like the committed version, follow these steps:

### Prerequisites
- **Xcode 15.0+** (or compatible version)
- **iOS 17.0+** deployment target
- **iPad device or iPad simulator** (iPhone testing not supported)
- **macOS 14.0+** for development

### Initial Setup

1. **Clone the repository:**
   ```bash
   git clone [your-github-repo-url]
   cd KAust
   ```

2. **Open the project:**
   - Open `KAust/KAust.xcodeproj` in Xcode
   - **Do NOT** open any `.xcworkspace` files

3. **Configure Code Signing:**
   - Select the KAust project in the navigator
   - Go to "Signing & Capabilities"
   - Set your Team and Bundle Identifier
   - Ensure "Automatically manage signing" is checked

### Critical Setup Steps

#### 1. Test Environment
- **ONLY test on iPad simulators or iPad devices**
- Recommended simulators: iPad Pro (11-inch), iPad Air (5th generation)
- **Do NOT test on iPhone** - UI is iPad-optimized only

#### 2. First Launch Setup
The app will start with **empty Core Data** - this is normal. You need to:

1. **Import MP4 files through Settings:**
   - Launch the app
   - Navigate to Settings
   - Use the file import feature to add MP4 karaoke files
   - Minimum file size: 5MB, Maximum: 150MB

2. **Authentication Setup:**
   - The app has role-based authentication
   - Default roles: Client, Admin, Dev, Owner
   - Each role has different feature access levels

#### 3. Expected Behavior After Setup

**Song List:**
- ✅ Fuzzy search with Levenshtein distance
- ✅ Scroll indicators visible (thin dark line on right)
- ✅ Touch scroll indicator to make it thicker for fast scrolling
- ✅ No color-changing List behavior (uses ScrollView + LazyVStack)

**Playlist:**
- ✅ Scroll indicators working
- ✅ Auto-scroll to bottom when adding songs
- ✅ Edit mode with swipe-to-delete

**Video Player:**
- ✅ Progress bar with white handle that stays attached during scrubbing
- ✅ Time display above progress bar during scrubbing
- ✅ Butter-smooth video dragging without jerky movement
- ✅ Video drag blocking during scroll operations
- ✅ Fullscreen mode with proper utility icon placeholders

### Build Configuration

1. **Deployment Target:** iOS 17.0+
2. **Supported Devices:** iPad only
3. **Orientation:** Portrait and Landscape
4. **Architecture:** arm64 (Apple Silicon/A-series)

### Troubleshooting

#### No Songs Visible
- This is expected on first launch
- Import MP4 files through Settings → File Import

#### Scroll Indicators Not Visible
- Ensure you're testing on iPad (not iPhone)
- Try scrolling - indicators appear during scroll
- Check that `showsIndicators: true` in SonglistView.swift

#### Video Player Issues
- Ensure MP4 files are properly imported
- Check file paths in Core Data
- Videos must be between 5MB-150MB

#### Performance Issues
- Test on iPad Air (5th gen) or newer
- Avoid iPhone simulators
- Clear Derived Data if build issues occur

### File Structure Overview
```
KAust/
├── KAust/
│   ├── Core/
│   │   ├── Models/ (Song, User, AppSong)
│   │   ├── Services/ (Authentication, etc.)
│   │   └── Data/ (Core Data models)
│   ├── Features/
│   │   ├── Authentication/
│   │   ├── SongList/ (Fuzzy search, scroll indicators)
│   │   ├── PlayList/ (Queue management)
│   │   ├── VideoPlayer/ (Drag, progress, controls)
│   │   └── Settings/
│   └── UI/
├── KAust.xcodeproj
└── README.md (this file)
```

### Version Compatibility
- This commit represents a fully working version
- All major features tested and functional
- Performance optimizations implemented
- UI/UX issues resolved

### Support
If the setup doesn't match the expected behavior:
1. Verify iPad-only testing
2. Check Core Data is empty (expected)
3. Import test MP4 files
4. Compare git commit hash with working version

---

**Last tested:** [Current Date]
**Commit:** [Your commit hash]
**Xcode Version:** [Your Xcode version] 