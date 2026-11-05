# Local example

Applies circuit-homepage to a throwaway Rocky Linux 10 container with systemd, with two services, a bookmark and a value from an env file. You need Conn3x and Podman.

Homepage runs under Podman inside that container, so the host container is privileged, which is simplest with rootful Podman. On a Mac, use the Podman machine's root connection. On Linux, use `sudo podman`:

```sh
export CONTAINER_CONNECTION=podman-machine-default-root   # macOS
export PODMAN="sudo podman"                               # Linux
./up.sh
conn3x init
conn3x apply
conn3x plan
```

The first apply takes a few minutes: it installs Podman, pulls Homepage's image, checks and writes the config files and waits for Homepage to listen. The second plan says `No changes.`

`main.tf` gives `services` as HCL and `bookmarks` as a YAML string, so you can see both forms. The first service's description is `{{HOMEPAGE_VAR_GREETING}}`, which Homepage fills in from the env file. That shows the substitution working; a real secret belongs in a widget setting, never a description.

Homepage listens on `127.0.0.1:3000` inside the container. To see the dashboard, forward that port over SSH, then open `http://localhost:3000`:

```sh
ssh -p 2222 -i id_ed25519 -o UserKnownHostsFile=known_hosts -L 3000:127.0.0.1:3000 root@127.0.0.1
```

[`check.mjs`](check.mjs) is what CI runs instead of a browser. Run it with Node inside Homepage's container:

```sh
podman exec -i circuit-homepage podman exec -i homepage node --input-type=module - < check.mjs   # sudo podman on Linux
```

`up.sh` listens on `127.0.0.1:2222`. Set `PORT` to use another port, and pass the same port to Conn3x with `-var port=PORT`. Set `CONTAINER_NAME` to name the container something other than `circuit-homepage`, and pass it to `down.sh` too. Set `CONTAINERFILE` to test another distro, such as one of the images in Conn3x's `test/images`, which CI uses.

`./down.sh` removes the container, its volumes, the key and the state.
