#!/usr/bin/env bash
# Runs integration_test/app_test.dart in headless Chrome.
# Usage: scripts/e2e_web.sh [extra flutter drive args, e.g. --no-headless]
# CHROME_EXECUTABLE and CHROMEDRIVER, when set, give the Chrome and
# chromedriver to use (CI sets them); otherwise the local ones are found.
set -euo pipefail

cd "$(dirname "$0")/.."

port=4444
mac_chrome='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
if [[ -n "${CHROME_EXECUTABLE:-}" ]]; then
  chrome_version=$("$CHROME_EXECUTABLE" --version)
elif [[ -x "$mac_chrome" ]]; then
  chrome_version=$("$mac_chrome" --version)
else
  chrome_version=$(google-chrome --version)
fi
chrome_version=$(grep -Eo '[0-9]+(\.[0-9]+){3}' <<<"$chrome_version")
chrome_major=${chrome_version%%.*}

major_of() { "$1" --version | grep -Eo '[0-9]+' | head -n 1; }

install_driver() {
  npx --yes @puppeteer/browsers@3 install "chromedriver@$1" \
    --path .chromedriver --format '{{path}}'
}

driver=''
# CHROMEWEBDRIVER is the chromedriver folder on GitHub-hosted runners.
for candidate in "${CHROMEDRIVER:-}" "$(command -v chromedriver || true)" \
  "${CHROMEWEBDRIVER:+$CHROMEWEBDRIVER/chromedriver}" \
  .chromedriver/chromedriver/*/*/chromedriver; do
  if [[ -x "$candidate" && "$(major_of "$candidate")" == "$chrome_major" ]]; then
    driver=$candidate
    break
  fi
done

if [[ -z "$driver" ]]; then
  echo "Installing chromedriver $chrome_version into .chromedriver/"
  # Fall back to the latest patch of the same build if the exact one is missing.
  driver=$(install_driver "$chrome_version" ||
    install_driver "${chrome_version%.*}")
fi

echo "Chrome $chrome_version, $("$driver" --version)"
mkdir -p .chromedriver
"$driver" --port="$port" >.chromedriver/chromedriver.log 2>&1 &
driver_pid=$!
trap 'kill "$driver_pid" 2>/dev/null || true' EXIT

for _ in {1..50}; do
  curl -fs "http://localhost:$port/status" >/dev/null && break
  kill -0 "$driver_pid" 2>/dev/null || {
    cat .chromedriver/chromedriver.log
    exit 1
  }
  sleep 0.2
done

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  -d web-server \
  --browser-name=chrome \
  --headless \
  --driver-port="$port" \
  ${CHROME_EXECUTABLE:+--chrome-binary="$CHROME_EXECUTABLE"} \
  "$@"
