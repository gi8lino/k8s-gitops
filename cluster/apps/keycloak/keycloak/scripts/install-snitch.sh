#!/bin/bash
set -euo pipefail

: "${SNITCH_VERSION:?SNITCH_VERSION must be set}"

version="${SNITCH_VERSION#v}"
jar="/providers/keycloak-snitch.jar"
temporary="${jar}.tmp"

# Read the version embedded in the JAR; no separate marker is needed.
jar_version() {
  unzip -p "$1" 'META-INF/maven/*/*/pom.properties' 2>/dev/null |
    sed -n 's/^version=//p'
}

installed_version=""
if [ -s "$jar" ]; then
  installed_version="$(jar_version "$jar")" || installed_version=""
fi

if [ "$installed_version" = "$version" ]; then
  echo "Snitch $SNITCH_VERSION already installed"
  exit 0
fi

trap 'rm -f "$temporary"' EXIT

url="https://github.com/gi8lino/keycloak-snitch/releases/download/${SNITCH_VERSION}/keycloak-snitch-${version}.jar"

echo "Downloading Snitch $SNITCH_VERSION"
curl -fLsS --retry 3 "$url" -o "$temporary"
test -s "$temporary"

# Verify the downloaded version before replacing the installed JAR.
downloaded_version="$(jar_version "$temporary")"
if [ "$downloaded_version" != "$version" ]; then
  echo "Downloaded JAR version does not match $SNITCH_VERSION" >&2
  exit 1
fi

mv "$temporary" "$jar"

# Remove older versioned JARs to prevent duplicate provider discovery.
rm -f /providers/keycloak-snitch-*.jar

echo "Snitch $SNITCH_VERSION installed"
