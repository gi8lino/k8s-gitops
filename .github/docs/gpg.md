# :closed_lock_with_key:&nbsp; Setting up GnuPG keys

:round_pushpin: Using SOPS with GnuPG allows to encrypt and decrypt secrets.

Create a GPG Key for Flux:

```sh
export GPG_TTY=$(tty)
export FLUX_KEY_NAME="k3s"

gpg --batch --full-generate-key <<EOF
%no-protection
Key-Type: 1
Key-Length: 4096
Subkey-Type: 1
Subkey-Length: 4096
Expire-Date: 0
Name-Real: ${FLUX_KEY_NAME}
EOF
```

Show the just created Flux GPG Key:

```sh
gpg --list-secret-keys "${FLUX_KEY_NAME}"
# pub   rsa4096 2021-03-11 [SC]
#       AB675CE4CC64251G3S9AE1DAA88ARRTY2C009E2D
# uid           [ultimate] Home cluster (Flux) <k8s-at-home@gmail.com>
# sub   rsa4096 2021-03-11 [E]
```

Export the fingerprint of the just created Flux GPG Key to the variable `FLUX_KEY_FP`:

```sh
export FLUX_KEY_FP=$(gpg --list-secret-keys "${FLUX_KEY_NAME}" | sed -n '/sec/{n;s/^\s*\s//;p;}')
```

Check if the exported fingerprint was extracted correctly:

```sh
echo ${FLUX_KEY_FP}
# AB675CE4CC64251G3S9AE1DAA88ARRTY2C009E2D
```

Create/update `.sops.yaml`:

```bash
cat << EOF > .sops.yaml
---
creation_rules:
  - encrypted_regex: ^(data|stringData|customRequestHeaders)$
    pgp: ${FLUX_KEY_FP}

EOF
```
