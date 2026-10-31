# Proposal: Arva AI Conversation Layout and Responsiveness Refactoring

## Why
Currently, the Arva AI conversation interface relies on a hidden mobile `Drawer` for historical conversations, making previous discussions hard to discover on desktop and tablet screens. On wide screens, the previous conversations panel should be open by default beside the main application sidebar, easily collapsible via a toggle button, and responsive across all device breakpoints. The main application sidebar also needs collapsible states to conserve space on laptops and tablets, while the chat workspace must dynamically adjust its width, anchor the message composer, prevent message occlusion, and format long responses gracefully.

## What Changes
1. **Previous AI Conversations Sidebar**:
   - Expanded by default on desktop/tablet viewports (width >= 1024px).
   - Embedded directly into the AI screen layout rather than confined to a hidden modal drawer.
   - Dedicated toggle button in the header toolbar to collapse and reopen the sidebar smoothly without breaking chat flow.
   - On mobile viewports (<600px) or small screens, automatically switches to an off-canvas drawer / overlay.
   - Proper alignment of titles, timestamps, active state indicators, and plan tags with clean text truncation.

2. **Main Application Sidebar Alignment & Collapsibility**:
   - Introduce a collapsible toggle for the main desktop sidebar in `AppShell` (toggling between expanded 260px and compact 72px rail mode), saving horizontal room on smaller desktop screens.
   - Consistent layout and visual hierarchy across all tabs.

3. **Adaptive Chat Workspace & Composer**:
   - The AI conversation workspace dynamically expands and reclaims available horizontal space when either sidebar is collapsed.
   - Message bubbles and action prompt ribbons maintain max-width bounds and fluid responsive layout.
   - Anchored bottom composer with responsive paddings and clean auto-scrolling that respects manual user browsing.

## Non-Goals
- Modifying backend APIs or database models.
- Changing core application colors, typography, or theme system.
