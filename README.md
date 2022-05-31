# My home infrastructure

## Creating secrets

To create secrets `openssl` should be installed.

```bash
openssl aes-256-cbc -base64 -pbkdf2 -kfile secrets.password -in file.txt -out secrets/file.txt.aes-256-cbc.base64
```

## Deploy

`colmena` package is required:

```bash
colmena apply -f gw.nix -v switch
```
