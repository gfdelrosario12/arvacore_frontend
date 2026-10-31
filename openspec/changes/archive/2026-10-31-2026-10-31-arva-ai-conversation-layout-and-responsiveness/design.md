# Design: Arva AI Responsive Multi-Sidebar Architecture

## Architecture Overview

The interface consists of a responsive layout system across viewports:
1. **Desktop (>= 1024px)**:
   - Level 1: Main Application Sidebar (`AppShell`), default 260px width, collapsible to 72px rail mode.
   - Level 2: Arva AI Previous Conversations Sidebar (`FarmingChatbotScreen`), default 280px width, open by default, collapsible via header icon button.
   - Level 3: Main Chat Workspace, filling remaining horizontal width, housing message list, ribbons, prompt chips, and bottom-anchored input bar.

2. **Tablet (600px - 1023px)**:
   - Level 1: Navigation Rail (72px).
   - Level 2: AI Conversations Sidebar, collapsible overlay or inline drawer (260px).
   - Level 3: Chat Workspace adapting fluidly.

3. **Mobile (< 600px)**:
   - Main Shell uses bottom navigation bar.
   - AI Screen hides inline conversation sidebar; displays a standard `Drawer` opened by an explicit History icon button in the AppBar.
   - Chat bubbles expand up to 90% of screen width.

## State Management
- `_isHistorySidebarOpen`: State flag initialized to `true` on desktop viewports (`>= 1024px`) and `false` on smaller screens.
- `_isAppSidebarCollapsed`: State flag in `AppShell` toggling between full 260px and 72px compact rail mode.
- Both sidebars transition smoothly using animated containers or responsive conditional sizing.
