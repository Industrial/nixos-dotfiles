#!/usr/bin/env bun

import {
  Actions,
  Color,
  EAttachMode,
  EBaseDirection,
  EExtendedDirection,
  EFocusFollowCursor,
  EPointerCommand,
  Input,
  type InputDevices,
  KeyBinding,
  KeyboardShortcut,
  Modes,
  Modifiers,
  Pointer,
  PointerBinding,
  River,
  type RiverModesDefinition,
  type RiverOptions,
  RiverctlExecuter,
  type RiverctlFeatures,
  Shortcuts,
  Tags,
} from 'river-wm-js'

// this this the example of how you can alias nested imports
// the syntax isn't very common so leaving it here
import EAxis = Actions.EAxis
import mapTags = Tags.mapTags
// multilevel aliasing
import ETagAction = Actions.Tags.ETagAction
import ETagActionScope = Actions.Tags.ETagActionScope
import TagAction = Actions.Tags.TagAction

const tileManager = 'rivertile'

const tagKeySums = {
  '1': 0b1,
  '2': 0b10,
  '3': 0b100,
  '4': 0b1000,
  '5': 0b10000,
  '6': 0b100000,
}

function mapTagKeySum(keySum: string) {
  return tagKeySums[keySum as keyof typeof tagKeySums]
}

// strongly recommended to preserve `Actions.Focus` notation for
// actions and modifiers since they use pretty common names.
// Not doing so, may result in name collisions
const defaultModeKeyBindings: KeyBinding<RiverctlFeatures>[] = [
  new KeyBinding(
    new Actions.Focus(EBaseDirection.PREVIOUS),
    new KeyboardShortcut([Modifiers.Super], 'J'),
  ),
  new KeyBinding(
    new Actions.Focus(EBaseDirection.NEXT),
    new KeyboardShortcut([Modifiers.Super], 'K'),
  ),
  new KeyBinding(
    new Actions.Swap(EBaseDirection.PREVIOUS),
    new KeyboardShortcut([Modifiers.Super, Modifiers.Shift], 'J'),
  ),
  new KeyBinding(
    new Actions.Swap(EBaseDirection.NEXT),
    new KeyboardShortcut([Modifiers.Super, Modifiers.Shift], 'K'),
  ),
  new KeyBinding(
    new Actions.SendLayoutCmd(tileManager, ['main-ratio', '-0.02']),
    new KeyboardShortcut([Modifiers.Super], 'H'),
  ),
  new KeyBinding(
    new Actions.SendLayoutCmd(tileManager, ['main-ratio', '+0.02']),
    new KeyboardShortcut([Modifiers.Super], 'L'),
  ),
  new KeyBinding(
    new Actions.SendLayoutCmd(tileManager, ['main-count', '+1']),
    new KeyboardShortcut([Modifiers.Super, Modifiers.Shift], 'H'),
  ),
  new KeyBinding(
    new Actions.SendLayoutCmd(tileManager, ['main-count', '-1']),
    new KeyboardShortcut([Modifiers.Super, Modifiers.Shift], 'L'),
  ),
  new KeyBinding(
    new Actions.CloseAction(),
    new KeyboardShortcut([Modifiers.Super], 'W'),
  ),
  new KeyBinding(
    new Actions.ToggleFullscreen(),
    new KeyboardShortcut([Modifiers.Super], 'F'),
  ),
  new KeyBinding(
    new Actions.ToggleFloat(),
    new KeyboardShortcut([Modifiers.Super, Modifiers.Shift], 'F'),
  ),
  new KeyBinding(
    new Actions.Spawn('rofi', ['-show', 'run']),
    new KeyboardShortcut([Modifiers.Super], 'R'),
  ),
  new KeyBinding(
    new Actions.Spawn('rofi', ['-show', 'drun']),
    new KeyboardShortcut([Modifiers.Super], 'D'),
  ),
  new KeyBinding(
    new Actions.Zoom(),
    new KeyboardShortcut([Modifiers.Super], 'Z'),
  ),
  new KeyBinding(
    new Actions.Move(EExtendedDirection.LEFT),
    new KeyboardShortcut([Modifiers.Super, Modifiers.Alt], 'H'),
  ),
  new KeyBinding(
    new Actions.Move(EExtendedDirection.DOWN),
    new KeyboardShortcut([Modifiers.Super, Modifiers.Alt], 'J'),
  ),
  new KeyBinding(
    new Actions.Move(EExtendedDirection.UP),
    new KeyboardShortcut([Modifiers.Super, Modifiers.Alt], 'K'),
  ),
  new KeyBinding(
    new Actions.Move(EExtendedDirection.RIGHT),
    new KeyboardShortcut([Modifiers.Super, Modifiers.Alt], 'L'),
  ),
  new KeyBinding(
    new Actions.Resize(EAxis.HORIZONTAL, -100),
    new KeyboardShortcut([Modifiers.Super, Modifiers.Ctrl], 'H'),
  ),
  new KeyBinding(
    new Actions.Resize(EAxis.VERTICAL, -100),
    new KeyboardShortcut([Modifiers.Super, Modifiers.Ctrl], 'J'),
  ),
  new KeyBinding(
    new Actions.Resize(EAxis.VERTICAL, +100),
    new KeyboardShortcut([Modifiers.Super, Modifiers.Ctrl], 'K'),
  ),
  new KeyBinding(
    new Actions.Resize(EAxis.HORIZONTAL, +100),
    new KeyboardShortcut([Modifiers.Super, Modifiers.Ctrl], 'L'),
  ),
  new KeyBinding(
    new Actions.Spawn('alacritty', []),
    new KeyboardShortcut([Modifiers.Super], 'T'),
  ),
  new KeyBinding(
    new Actions.Exit(),
    new KeyboardShortcut([Modifiers.Super, Modifiers.Shift], 'Q'),
  ),
  new KeyBinding(
    new Actions.CloseAction(),
    new KeyboardShortcut([Modifiers.Super], 'W'),
  ),
  ...mapTags(
    [Modifiers.Super],
    Object.getOwnPropertyNames(tagKeySums),
    TagAction.bind(null, ETagAction.SET, ETagActionScope.FOCUSED),
    mapTagKeySum,
  ),
  ...mapTags(
    [Modifiers.Super, Modifiers.Ctrl],
    Object.getOwnPropertyNames(tagKeySums),
    TagAction.bind(null, ETagAction.SET, ETagActionScope.VIEW),
    mapTagKeySum,
  ),
  ...mapTags(
    [Modifiers.Super, Modifiers.Shift],
    Object.getOwnPropertyNames(tagKeySums),
    TagAction.bind(null, ETagAction.TOGGLE, ETagActionScope.FOCUSED),
    mapTagKeySum,
  ),
  ...mapTags(
    [Modifiers.Super, Modifiers.Alt],
    Object.getOwnPropertyNames(tagKeySums),
    TagAction.bind(null, ETagAction.TOGGLE, ETagActionScope.VIEW),
    mapTagKeySum,
  ),
]

const defaultModePointerBindings: PointerBinding<RiverctlFeatures>[] = [
  new PointerBinding(
    EPointerCommand.MOVE_VIEW,
    new Shortcuts.PointerShortcut([Modifiers.Super], Pointer.BTN_LEFT),
  ),
  new PointerBinding(
    EPointerCommand.RESIZE_VIEW,
    new Shortcuts.PointerShortcut([Modifiers.Super], Pointer.BTN_RIGHT),
  ),
]

const defaultMode = new Modes.EnterableMode(
  'normal',
  new KeyboardShortcut([Modifiers.Super, Modifiers.Shift], 'Z'),
  Modes.ALL,
  { keyboard: defaultModeKeyBindings, pointer: defaultModePointerBindings },
)
const testMode: Modes.EnterableMode<RiverctlFeatures> = new Modes.EnterableMode(
  'test',
  new KeyboardShortcut([Modifiers.Super, Modifiers.Shift], 'x'),
  [defaultMode],
  {},
)

const modes: RiverModesDefinition<RiverctlFeatures> = {
  specialModes: {
    DEFAULT_MODE: defaultMode,
    LOCK_MODE: new Modes.NamedMode('locked', {}),
  },
  otherModes: [testMode],
}

const options: RiverOptions = {
  theme: {
    borderWidth: 2,
    borderColorFocused: new Color('0xeceff4'),
    borderColorUnfocused: new Color('0x81a1c1'),
    borderColorUrgent: new Color('0xbf616a'),
    backgroundColor: new Color('0x2e3440'),
  },
  focusFollowsCursor: EFocusFollowCursor.NORMAL,
  attachMode: EAttachMode.BOTTOM,
}

const inputDevices: InputDevices = {
  'pointer-1267-12608-MSFT0001:01_04F3:3140_Touchpad': {
    events: Input.EEvents.DISABLED_ON_EXTERNAL_MOUSE,
    drag: true,
    tap: true,
    tapButtonMap: Input.ETapButtonMap.LEFT_RIGHT_MIDDLE,
    disableWhileTyping: true,
    scrollMethod: { kind: 'two-finger' },
  },
}

const river = new River(modes, options, {
  input: inputDevices,
  tileManager,
  startupActions: [
    new Actions.Spawn('dbus-update-activation-environment', [
      '--systemd',
      'WAYLAND_DISPLAY',
      'XDG_CURRENT_DESKTOP=river',
      'XDG_CONFIG_DIRS',
    ]),
    new Actions.Spawn('systemctl', [
      '--user',
      'import-environment',
      'WAYLAND_DISPLAY',
      'XDG_CONFIG_DIRS',
    ]),
    new Actions.Spawn('systemctl', [
      '--user',
      'set-environment',
      'XDG_CURRENT_DESKTOP=river' /* `XDG_CONFIG_DIRS=${process.env["XDG_CONFIG_DIRS"]}:/etc/xdg` */,
    ]),
  ],
})

const riverctl = new RiverctlExecuter(river)
riverctl.apply()
