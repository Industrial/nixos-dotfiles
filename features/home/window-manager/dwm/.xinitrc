#!/usr/bin/env bash

set_wallpaper() {
  # TODO: Could make this random
  # TODO: Could integrate this into startdwm and make it cycle
  feh --bg-fill /home/tom/Pictures/Wallpapers/Abstract/wallhaven-l35myl.jpg
  ~/.fehbg &
}

set_display() {
  # xrandr --output HDMI-A-0      --rotate normal --size 3840x2160 --rate 60.00 --primary &&
  xrandr --output DisplayPort-1 --rotate normal --size 7680x2160 --rate 120.00 --primary
  # xrandr --output DisplayPort-0 --rotate normal --size 1920x1080 --rate 60.00 --right-of HDMI-A-0
}

set_date() {
  while true; do
    xsetroot -name "$(date '+%Y-%m-%d %H:%M:%S')"
    sleep 1
  done
}

# Call the functions in the background
(set_display &) &
(set_wallpaper &) &
(set_date &) &

dwm &

# This command keeps the script running, so that the other commands like the
# while loop can run in the background.
wait
