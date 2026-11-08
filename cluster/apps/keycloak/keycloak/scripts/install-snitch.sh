#!/bin/sh
set -e

version="${SNITCH_VERSION#v}"
jar="/providers/keycloak-snitch.jar"
marker="/providers/.snitch-version"

if [ -s "$jar" ] &&
   [ "$(cat "$marker" 2>/dev/null)" = "$SNITCH_VERSION" ]; then
  echo "Snitch $SNITCH_VERSION already installed"
  exit 0
fi

url="https://github.com/gi8lino/keycloak-snitch/releases/download/${SNITCH_VERSION}/keycloak-snitch-${version}.jar"

echo "Downloading Snitch $SNITCH_VERSION"
curl -fLsS --retry 3 "$url" -o "${jar}.tmp"
test -s "${jar}.tmp"

# Remove older versioned Snitch JARs.
rm -f /providers/keycloak-snitch-*.jar

mv "${jar}.tmp" "$jar"
printf '%s\n' "$SNITCH_VERSION" > "$marker"

echo "Snitch $SNITCH_VERSION installed"
