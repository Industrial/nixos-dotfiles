import Bun from 'bun'

const cmd = async (command: string) => {
  const commandArray = command.split(' ')
  const process = Bun.spawn(commandArray)
  await process.exited
  return process.stdout
}

// Terminal
await cmd('riverctl map normal Super Return spawn alacritty')

// App Launcher
await cmd('riverctl map normal Super+Shift P spawn "rofi -show drun"')

// Close Window
await cmd('riverctl map normal Super Backspace close')

// Exit River
await cmd('riverctl map normal Super+Control+Shift Backspace exit')

// Focus Next/Previous Window
await cmd('riverctl map normal Super+J focus-view next')
await cmd('riverctl map normal Super+K focus-view previous')

// Swap with Next/Previous Window
await cmd('riverctl map normal Super+Control J swap next')
await cmd('riverctl map normal Super+Control K swap previous')

// Increase/Decrease the main ratio of rivertile(1)
await cmd(
  'riverctl map normal Super+Shift H send-layout-cmd rivertile "main-ratio -0.05"',
)
await cmd(
  'riverctl map normal Super+Shift L send-layout-cmd rivertile "main-ratio +0.05"',
)

// Increment/Decrement the main count of rivertile(1)
await cmd(
  'riverctl map normal Super+Control+Shift H send-layout-cmd rivertile "main-count +1"',
)
await cmd(
  'riverctl map normal Super+Control+Shift L send-layout-cmd rivertile "main-count -1"',
)

// Super+Space to toggle float
await cmd('riverctl map normal Super Space toggle-float')

// Super+F to toggle fullscreen
await cmd('riverctl map normal Super+Shift M toggle-fullscreen')

// TODO: doesn't work.
// Focus Next/Previous Tag
// riverctl map normal Super+Control H focus-previous-tag
// riverctl map normal Super+Control L focus-next-tag

// TODO: Doesn't work.
// Send Client to Next/Previous Tag
// riverctl map normal Super+Control H send-previous-tag
// riverctl map normal Super+Control L send-next-tag

// Focus Next/Previous Output
// riverctl map normal Super Period focus-output next
// riverctl map normal Super Comma focus-output previous

// Send to Next/Previous Output
// riverctl map normal Super+Control Period send-to-output next
// riverctl map normal Super+Control Comma send-to-output previous

// Bump the focused view to the top of the layout stack
// riverctl map normal Super Return zoom

// Super+Alt+{H,J,K,L} to move views
// riverctl map normal Super+Alt H move left 100
// riverctl map normal Super+Alt J move down 100
// riverctl map normal Super+Alt K move up 100
// riverctl map normal Super+Alt L move right 100

// Super+Alt+Control+{H,J,K,L} to snap views to screen edges
// riverctl map normal Super+Alt+Control H snap left
// riverctl map normal Super+Alt+Control J snap down
// riverctl map normal Super+Alt+Control K snap up
// riverctl map normal Super+Alt+Control L snap right

// Super+Alt+Shift+{H,J,K,L} to resize views
// riverctl map normal Super+Alt+Shift H resize horizontal -100
// riverctl map normal Super+Alt+Shift J resize vertical 100
// iverctl map normal Super+Alt+Shift K resize vertical -100
// riverctl map normal Super+Alt+Shift L resize horizontal 100

// Super + Left Mouse Button to move views
// riverctl map-pointer normal Super BTN_LEFT move-view

// Super + Right Mouse Button to resize views
// riverctl map-pointer normal Super BTN_RIGHT resize-view

// Super + Middle Mouse Button to toggle float
// riverctl map-pointer normal Super BTN_MIDDLE toggle-float

// Super+{Up,Right,Down,Left} to change layout orientation
// riverctl map normal Super Up    send-layout-cmd rivertile "main-location top"
// riverctl map normal Super Right send-layout-cmd rivertile "main-location right"
// riverctl map normal Super Down  send-layout-cmd rivertile "main-location bottom"
// riverctl map normal Super Left  send-layout-cmd rivertile "main-location left"

// Declare a passthrough mode. This mode has only a single mapping to return to
// normal mode. This makes it useful for testing a nested wayland compositor
// riverctl declare-mode passthrough

// Super+F11 to enter passthrough mode
// riverctl map normal Super F11 enter-mode passthrough

// Super+F11 to return to normal mode
// riverctl map passthrough Super F11 enter-mode normal

// const getLastInsertedView = async () =>
//   await cmd('riverctl get-last-inserted-view')

// const startOnTag = async (program: string, tag: number) => {
//   await cmd(`${program} &`)
//   const viewId = await getLastInsertedView()
//   await cmd(`riverctl set-view-tags ${viewId} ${tag}`)
// }

// for (const [i, program] of autoStartPrograms) {
//   await startOnTag(program, tags[i])
// }

// 30 is the maximum tag
type TagName = string
type TagKeybind = string
type TagMask = number
type TagPrograms = Array<string>

const tags: Array<[TagName, TagKeybind, TagMask, TagPrograms]> = [
  ['1:WWW', '1', 1 << 0, ['firefox']],
  ['2:DEV', '2', 1 << 1, ['code']],
  ['3:TRM', '3', 1 << 2, ['alacritty --working-directory $HOME/Code']],
  ['4:GIT', '4', 1 << 3, ['gitkraken']],
  ['5:SYS', '5', 1 << 4, ['alacritty -e zellij']],
  ['6:MDA', '6', 1 << 5, ['spotify']],
  ['7:???', '7', 1 << 6, []],
  [
    '8:COM',
    '8',
    1 << 7,
    [
      // TODO: This one takes a really long time to start, so it won't start on
      //       the right tag. Not sure how to handle this.
      //'Discord'
    ],
  ],
  ['9:GAM', '9', 1 << 8, ['lutris']],
  ['0:???', '0', 1 << 9, []],
  ['Q:???', 'Q', 1 << 10, []],
  ['W:???', 'W', 1 << 11, []],
  ['E:???', 'E', 1 << 12, []],
  ['R:???', 'R', 1 << 13, []],
  ['T:???', 'T', 1 << 14, []],
  ['Y:???', 'Y', 1 << 15, []],
  ['U:???', 'U', 1 << 16, []],
  ['I:???', 'I', 1 << 17, []],
  ['O:???', 'O', 1 << 18, []],
  ['P:???', 'P', 1 << 19, []],
]

for (const [name, key, tag, programs] of tags) {
  // // Swap to the tag
  // await cmd(`riverctl set-focused-tags ${tag}`)
  // await delay(200)
  // // Start programs
  // for (const program of programs) {
  //   cmd(`${program}`)
  // }
  // // Wait a second
  // await delay(500)

  // Set keybinds
  // Super+[1-9] to focus tag [0-8]
  await cmd(`riverctl map normal Super ${key} set-focused-tags ${tag}`)
  // Super+Control+[1-9] to tag focused view with tag [0-8]
  await cmd(`riverctl map normal Super+Control ${key} set-view-tags ${tag}`)
  // Super+Alt+[1-9] to toggle focus of tag [0-8]
  await cmd(`riverctl map normal Super+Alt ${key} toggle-focused-tags ${tag}`)
  // Super+Control+Alt+[1-9] to toggle tag [0-8] of focused view
  await cmd(
    `riverctl map normal Super+Control+Alt ${key} toggle-view-tags ${tag}`,
  )
}

// Settings

// Set background and border color
await cmd('riverctl background-color 0x002b36')
await cmd('riverctl border-color-focused 0x93a1a1')
await cmd('riverctl border-color-unfocused 0x586e75')

// Set keyboard repeat rate
await cmd('riverctl set-repeat 50 300')

// Make all views with an app-id that starts with "float" and title "foo" start floating.
await cmd('riverctl rule-add -app-id "float*" -title "foo" float')

// Make all views with app-id "bar" and any title use client-side decorations
await cmd('riverctl rule-add -app-id "bar" csd')

// Notification Daemon
cmd('mako')

// Top Bar
cmd('waybar')

// Layout Generator

// Set the default layout generator to be rivertile and start it. River will
// send the process group of the init executable SIGTERM on exit.
await cmd('riverctl default-layout rivertile')
cmd('rivertile -view-padding 1 -outer-padding 0')
