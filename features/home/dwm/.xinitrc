#!/usr/bin/env bash

(
  sleep 2 && 
  (
    xrandr --output HDMI-A-0      --rotate normal --size 3840x2160 --rate 60.00 --primary &&
    xrandr --output DisplayPort-1 --rotate normal --size 1920x1080 --rate 60.00 --left-of  HDMI-A-0 &&
    xrandr --output DisplayPort-0 --rotate normal --size 1920x1080 --rate 60.00 --right-of HDMI-A-0
  ) &&
  (
    # TODO: Could make this random
    # TODO: Could integrate this into startdwm and make it cycle
    feh --bg-fill /home/tom/Pictures/Wallpapers/Abstract/wallhaven-l35myl.jpg
    ~/.fehbg &
  )
) &

dwm