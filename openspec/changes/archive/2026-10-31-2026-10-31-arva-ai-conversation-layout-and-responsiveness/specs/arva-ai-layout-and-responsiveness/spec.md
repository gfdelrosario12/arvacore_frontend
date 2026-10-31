# Spec: Arva AI Layout and Responsiveness

## ADDED Requirements

### Requirement: Previous AI Conversations Sidebar Default State and Responsiveness
The system SHALL display the previous conversations sidebar expanded by default on desktop and tablet viewports, and SHALL provide a toggle button to collapse and re-expand it.

#### Scenario: Desktop initial view
- **GIVEN** a user accesses the Arva AI interface on a screen width >= 600px
- **WHEN** the screen loads
- **THEN** the conversation history sidebar is visible and expanded alongside the chat workspace by default.

#### Scenario: Toggling sidebar visibility on desktop
- **GIVEN** the conversation history sidebar is open on a desktop screen
- **WHEN** the user clicks the toggle sidebar button in the Arva AI app bar
- **THEN** the conversation history sidebar collapses smoothly and the main chat workspace expands to consume the full available width.

#### Scenario: Mobile drawer presentation
- **GIVEN** a user accesses Arva AI on a mobile viewport (< 600px)
- **WHEN** the screen loads
- **THEN** the chat workspace occupies the full width and the conversation history is accessible via an overlay drawer.

### Requirement: Main Application Sidebar Collapsible State
The system SHALL support a collapsible rail mode on desktop viewports for the main ArvaCore navigation sidebar to maximize AI chat space.

#### Scenario: Collapsing main sidebar
- **GIVEN** the user is viewing the application on a desktop browser
- **WHEN** the user clicks the collapse button on the main navigation sidebar
- **THEN** the sidebar width reduces from 260px to 72px rail mode, displaying centered navigation icons without text labels.

### Requirement: Responsive Chat Workspace and Composer
The AI chat workspace SHALL dynamically adapt its width and maintain anchored message composition controls without overlapping conversation messages or obscuring responses.

#### Scenario: Message composer anchoring and scroll integrity
- **GIVEN** a conversation with multiple messages and long AI responses
- **WHEN** new messages are added or the workspace width is resized
- **THEN** the message composer remains anchored at the bottom without overlapping the last message, and the viewport maintains readable maximum line length.
