lowercase() {
  echo "$1" | awk '{print tolower($0)}'
}