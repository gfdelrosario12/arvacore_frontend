# Tasks: Arva AI Conversation Layout and Responsiveness Refactoring

## Implementation Tasks

- [ ] 1. **Previous AI Conversations Sidebar in FarmingChatbotScreen**
  - [ ] 1.1 Add `_isHistorySidebarOpen` boolean state initialized based on viewport width (open by default on desktop).
  - [ ] 1.2 Implement dedicated sidebar toggle button in AppBar with responsive tooltip and icon.
  - [ ] 1.3 Implement inline collapsible panel for desktop and tablet screens alongside chat workspace.
  - [ ] 1.4 Maintain mobile `Drawer` fallback on screens `< 600px`.
  - [ ] 1.5 Improve typography, badge styling, timestamps, and hover/active states for conversation items.

- [ ] 2. **Main Application Sidebar Refactoring in AppShell**
  - [ ] 2.1 Add collapsibility toggle for desktop sidebar (260px expanded vs 72px compact rail).
  - [ ] 2.2 Align top bar, navigation destinations, and icons cleanly across all screen sizes.

- [ ] 3. **Chat Workspace Dynamic Layout & Composer**
  - [ ] 3.1 Ensure chat container reclaims 100% of remaining horizontal space when conversation sidebar is collapsed.
  - [ ] 3.2 Anchor message composer securely at bottom with proper padding and safe area handling.
  - [ ] 3.3 Ensure list view scrolls smoothly and maintains scroll position when users review previous messages.

- [ ] 4. **Testing & Verification**
  - [ ] 4.1 Run unit and widget tests for responsive layout and chat features.
  - [ ] 4.2 Run static analysis (`dart analyze`).
  - [ ] 4.3 Validate and archive OpenSpec change.
  - [ ] 4.4 Commit and synchronize Git changes.
