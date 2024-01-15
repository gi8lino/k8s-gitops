# configarr

This script is designed to read an XML configuration file and update its node values based on corresponding environment variables. It's useful for dynamically configuring applications based on environment settings in environments like Docker containers.

## Requirements

- A POSIX-compliant shell (`sh`)
- The `sed` command available in your environment
- The `grep` command available in your environment
- The `mktemp` command for creating a temporary file

## Usage

```sh
./update_config.sh [XML_FILE] [PREFIX]
```
