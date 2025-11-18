# BrainFish v1.2.0 - Reminders Sync Release

## 🎉 Major New Feature: Apple Reminders Integration

Two-way sync between BrainFish tasks and Apple Reminders, allowing you to manage your ADHD tasks across all your Apple devices.

### What's New?

BrainFish now optionally syncs with Apple Reminders, creating a dedicated "BrainFish" list that stays in sync with your swimming fish tasks.

## ✨ Key Features

### 📱 Two-Way Sync
- **BrainFish → Reminders**: Tasks created in BrainFish automatically appear in your Reminders app
- **Reminders → BrainFish**: Reminders added to the "BrainFish" list appear as swimming fish
- **Real-time Updates**: Changes sync automatically with smart debouncing (1.5s delay)
- **Conflict Resolution**: Timestamp-based conflict resolution ensures the latest changes win

### 🔄 Intelligent Sync Behavior
- **Dedicated List**: Creates a "BrainFish" list in Reminders (doesn't clutter your other lists)
- **Selective Sync**: Only syncs incomplete tasks (completed tasks stay local)
- **Deletion Tracking**: Remembers when you delete a reminder so it doesn't recreate it
- **Optional**: Completely opt-in via Settings → Fish tab

### 🎯 Settings & Controls
- **Enable/Disable Toggle**: Turn sync on/off anytime in Settings
- **Permission Request**: Proper macOS permission dialog on first enable
- **Status Indicators**: Clear console logging for sync operations

## 🔧 Technical Details

### Architecture
- **ReminderService**: Handles all EventKit (Reminders) operations
- **SyncEngine**: Two-way sync with debouncing and conflict resolution
- **Sandboxed**: Proper app sandboxing with calendar entitlements

### Smart Features
- **Debounced Sync**: 1.5-second delay to batch multiple changes
- **Change Detection**: Listens to EventKit database changes for instant updates
- **UUID Linking**: Each reminder stores task UUID for reliable matching
- **Deletion Memory**: Tracks deleted reminders to prevent recreation

### Sync Behavior Details
- **New Tasks**: Automatically create reminders when created in BrainFish
- **Task Updates**: Changes to title, notes, or due date sync both ways
- **Task Completion**: Marking complete in either app syncs to the other
- **Reminder Deletion**: Deleting from Reminders removes the link but keeps the fish task
- **Task Deletion**: Deleting a fish task also deletes its reminder

## 📝 Changes from v1.1.0

### Added
- Complete Apple Reminders integration with EventKit
- Two-way sync engine with conflict resolution
- "Sync with Apple Reminders" toggle in Fish settings
- Dedicated "BrainFish" reminder list creation
- Calendar entitlement for sandboxed Reminders access
- Deletion tracking to prevent unwanted reminder recreation
- Permission request flow with Info.plist usage description

### Technical Changes
- Extended Task model with EventKit properties:
  - `notes: String?` - Task notes/description
  - `dueDate: Date?` - Task due date
  - `isCompleted: Bool` - Completion status
  - `reminderID: String?` - Link to EKReminder
  - `lastModified: Date` - For conflict resolution
  - `reminderDeleted: Bool` - Deletion tracking
- New files:
  - `ReminderService.swift` - EventKit operations wrapper
  - `SyncEngine.swift` - Two-way sync logic
- Updated `BrainFish.entitlements` with calendar access
- Updated `Info.plist` with NSRemindersFullAccessUsageDescription

### Fixed
- Sync only targets BrainFish list (not all reminder lists)
- Deleted reminders no longer recreate automatically
- Proper main actor isolation for EventKit operations

## 🚀 Getting Started

1. **Update to v1.2.0**
2. **Enable Sync**:
   - Open Settings → Fish tab
   - Toggle "Sync with Apple Reminders" ON
   - Grant permission when prompted
3. **Check Reminders App**: You'll see a new "BrainFish" list
4. **Start Syncing**: Your fish tasks and reminders stay in sync!

## 💡 Tips

- Sync is **completely optional** - turn it on only if you want it
- The "BrainFish" list is **dedicated** - your other reminder lists aren't affected
- Delete reminders from the BrainFish list to **unlink** them from fish tasks
- Deleted reminders **won't recreate** automatically
- Turn off sync to **pause** synchronization (doesn't delete anything)

## 🐛 Known Issues

None currently reported for this release.

## 🙏 Credits

Developed with assistance from Claude Code (Anthropic)

---

**Full Changelog**: https://github.com/skaag/BrainFish/compare/v1.1.0...v1.2.0
