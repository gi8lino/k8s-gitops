# configarr

This script is designed to read an XML configuration file and update its node values based on corresponding environment variables. It's useful for dynamically configuring applications based on environment settings in environments like Docker containers.

## Requirements

- A POSIX-compliant shell (`sh`)
- The `xmlstarlet` command-line tool

## Usage

```sh
./update_config.sh -c [XML_FILE] -p [PREFIX]
```
