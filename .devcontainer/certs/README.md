# Extra root certificates

Every `*.crt` file in this folder is added to the container's OS trust store when
the image is built (see `../Dockerfile`). Use this for an internal or corporate
proxy **root CA** certificate in PEM format.

- Add only **public** CA certificates. Never put private keys here.
- `*.crt`, `*.pem`, and `*.key` files in this folder are ignored by Git. If your
  team wants to share a public corporate CA in source control, deliberately
  change `.gitignore` and get your security team's approval first.
- After adding or removing a certificate, run **Dev Containers: Rebuild
  Container**.
