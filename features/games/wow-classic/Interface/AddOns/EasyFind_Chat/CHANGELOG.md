# Changelog

All notable changes to EasyFind Chat will be documented in this file.

---

## [1.1.0] - 2026-11-13

### Changed
- **Notifications are for private messages by default**: only whispers and Battle.net whispers count on the chat button and play the message sound. Party, raid, instance, guild and officer chat start muted, as Say, Yell and the channels already did; a message that names you still counts. The new switch Mute group and guild chat turns this off, and a chat's own Mute or Unmute still wins

### Fixed
- **Battle.net chats**: each chat stays with its friend after a logout. Before, a chat could show another friend's name or none, a new whisper could land in another friend's chat, and a reply could reach a different friend. Chats saved earlier are sorted by friend on the first login; lines already filed under the wrong friend stay where they are

---

## [1.0.2] - 2026-11-09

### Fixed
- **The chat button's count**: counts the conversations the list shows, this character's, not every character's
- **WoW Forever**: a chat line the client withholds (a level-up's "You have learned a new spell") no longer raises an error
- **A client dialog's text box** with the keyboard focus no longer raises an error when the messenger looks at the focus
- **An EasyFind older than 4.0.0** gets one chat line asking for the update instead of errors

---

## [1.0.1] - 2026-11-03

### Fixed
- **Sidebar**: the conversation list runs down to the line under it, its last row cut there, instead of stopping short with a gap

---

## [1.0.0] - 2026-10-21

### Added
- **The messenger**: whispers and channels as conversations with threads and history, a composer with recipients and channel suggestions, emotes, and a window that folds its header or title away
- **In EasyFind**: a Chat tile in the extensions menu, a launcher row for the typed name, and the search bar finds conversations and messages and sends results and notes to a conversation
- **Notes**: Ctrl+Right-click on a link in the messenger opens its note
- **Clients**: retail, WoW Forever, Classic Era and TBC Anniversary
