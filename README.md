# Learn VS Code Dev Containers with a Dockerfile: C#, Azure CLI, and Bicep

A small, working **Dockerfile + Features** example with .NET 10 LTS, a
one-endpoint ASP.NET Core API, and five guided exercises. Use this approach for a
single-container workspace that needs custom OS packages, proprietary SDKs,
internal root certificates, or bespoke build steps that no Feature provides. No
Docker Compose, Azure account, or Azure deployment is needed.

## 1. The mental model

```text
Your computer (host)
  VS Code UI + Dev Containers extension + browser + Docker engine
    |
    +-- docker build, using .devcontainer/ as the build context
    |     Dockerfile: base image + apt packages + root CAs + ENV + config file
    |       --> Features layered on top: .NET 10, Azure CLI + Bicep
    |
    +-- Linux development container (a running instance of that image)
          VS Code server + C# / Bicep extensions + terminal + running API
            |
            +-- /workspaces/<folder> --> your project folder on the host

Host browser --> forwarded localhost port --> API on container port 8080
```

- The **Dockerfile** is a recipe that turns a base image into *your* image. Each
  instruction (`RUN`, `COPY`, `ENV`, ...) produces a cached **layer**.
- **Features** still install .NET, Azure CLI, and Bicep. Dev Containers builds
  your Dockerfile first and then runs Feature installers on top of it. A Dockerfile
  and Features are not either/or choices.
- The **build context** is the folder sent to Docker for `COPY`. Here it is
  `.devcontainer/`, so the Dockerfile can copy `certs/` and `config/`, but not
  `src/`.
- The project folder is **bind-mounted** at runtime, not copied into the image.
  Editing source changes the host files immediately and needs no image rebuild.
- This is a **development image**, not a production image for the API.

### Which approach should I choose?

| Approach | Best for |
| --- | --- |
| `image` + Features | Standard toolchains that already have Features. Start here. |
| **`build.dockerfile` + Features** | **One container that also needs custom `apt-get` packages, internal root CAs, baked-in config files or environment variables, or vendor SDK install steps.** |
| Docker Compose | A workspace that needs several containers, such as an app plus a database. |

Prefer a Feature when one exists: it is reusable and versioned. Add a Dockerfile
for what remains, and keep it small.

## 2. Prerequisites on the host

1. Install [VS Code](https://code.visualstudio.com/).
2. Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).
3. Install and start a Docker engine. On Windows, Docker Desktop with the WSL 2
   backend is a common option. Use **Linux containers**, not Windows containers.
   Check Docker Desktop's current licensing requirements for your use.
4. In a **host terminal**, check:

   ```text
   docker version
   ```

   Both Client and Server should be reported. A missing engine/pipe error means
   Docker is not ready yet.

Internet access is needed to download the base image, packages, Features, tools,
extensions, and dependencies. Behind a TLS-inspecting corporate proxy, you may
need to add your organisation's root CA first; see
[Corporate proxies and root certificates](#corporate-proxies-and-root-certificates).
You do **not** need .NET, Azure CLI, or Bicep on the host. C# Dev Kit has its own
[licensing terms](https://code.visualstudio.com/docs/csharp/cs-dev-kit-faq).

## 3. Open and try the example

1. Open this folder in VS Code.
2. Run **Dev Containers: Reopen in Container** from the Command Palette.
3. Wait for the image build, Feature installation, and post-create restore to
   finish. Select **show log** in the notification to watch the Dockerfile steps
   run. The remote indicator should then show **Dev Container**.
4. Open a **new VS Code terminal**. From now on, all shell commands in this guide
   are **Bash commands inside the container, from the project root**, unless
   explicitly labelled otherwise. Container paths use `/`, even on a Windows host.
5. Check the tools:

   ```bash
   dotnet --version
   az version
   bicep --version
   sqlite3 --version
   dos2unix --version
   shellcheck --version
   echo "$HELLO_GREETING"
   ```

   Expect a `10.0.x` SDK, Azure CLI and Bicep version details, the versions of
   three packages installed by the Dockerfile, and
   `Hello from a Dockerfile-built dev container!`.
6. Build and run:

   ```bash
   dotnet build src/HelloDockerfile/HelloDockerfile.csproj
   dotnet run --project src/HelloDockerfile/HelloDockerfile.csproj --launch-profile http --no-build
   ```

7. Leave that terminal running. Open VS Code's **Ports** view and use **Open in
   Browser** for **Hello Dockerfile API**. Normally the host URL is
   <http://localhost:8080/>. If that host port was busy, use the actual forwarded
   address in the Ports view instead.

   Expected response:

   ```json
   {"message":"Hello from a Dockerfile-built dev container!"}
   ```

   The message is not in the C# code. It comes from an environment variable baked
   into the image by the Dockerfile.
8. In a **second container terminal**, verify the endpoint directly:

   ```bash
   curl --fail http://localhost:8080/
   ```

   Press **Ctrl+C** in the running API terminal when finished.

The app intentionally uses HTTP for this local exercise so development
certificates do not distract from learning containers. No Azure service is called.

## 4. What each file does

```text
.devcontainer/
  devcontainer.json                 Development environment definition
  Dockerfile                        Custom image: packages, root CAs, ENV, config
  certs/README.md                   Drop zone for extra root CA *.crt files
  config/learning.conf              Config file copied into the image
.vscode/
  launch.json                       Named F5 debugging configuration
src/HelloDockerfile/
  HelloDockerfile.csproj            .NET 10 web project
  Program.cs                        One GET / endpoint reading HELLO_GREETING
  Properties/launchSettings.json    Shared HTTP launch profile
infra/
  main.bicep                        Optional local Bicep compilation sample
global.json                         Selects the .NET 10 SDK family
.gitattributes                      Keeps LF line endings for Linux files
.gitignore                          Excludes build outputs and test certificates
```

### Container settings

Open [`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json).

| Setting | Why it is here |
| --- | --- |
| `name` | A friendly label in VS Code. |
| `build.dockerfile` | Builds the image from [`Dockerfile`](.devcontainer/Dockerfile), resolved relative to `devcontainer.json`. It replaces the `image` property. |
| `build.context` | The folder sent to Docker, also relative to `devcontainer.json`. `"."` means `.devcontainer/`, which keeps builds small and makes `COPY certs/` work. |
| `build.args` | Values for `ARG` instructions. `IMAGE_GREETING` becomes the `HELLO_GREETING` environment variable. |
| `features` / `dotnet:2` | Installs the .NET SDK on top of your Dockerfile image; `version: "10.0"` selects .NET 10. |
| `features` / `azure-cli:1` | Installs Azure CLI; `installBicep: true` also installs Bicep. |
| `remoteUser` | Runs editor processes and terminals as `vscode`, not root. Dockerfile `RUN` steps and Feature installers run as root during the build. |
| `customizations.vscode.extensions` | Installs C# Dev Kit and Bicep language tooling in the remote environment. |
| `forwardPorts` / `portsAttributes` | Forwards and labels container port 8080. It does not start the API. |
| `postCreateCommand` | Restores the C# project after the workspace is mounted. Source code is not available during the Dockerfile build. |

The base image tag and Feature major versions (`:2` and `:1`) are **not
immutable pins**; they receive updates, as do the `apt` packages. Rebuilding later
can produce a slightly different image. Production teams may pin image digests and
exact package versions for stricter reproducibility. `.devcontainer/devcontainer-lock.json`
records the resolved Feature versions.

[`global.json`](global.json) requests SDK `10.0.100` with `latestFeature`
roll-forward. The project targets `net10.0`.

### The Dockerfile, section by section

Open [`.devcontainer/Dockerfile`](.devcontainer/Dockerfile).

| Section | What it shows |
| --- | --- |
| `FROM mcr.microsoft.com/devcontainers/base:ubuntu24.04` | Start from a Dev Containers base image: Ubuntu, Git, common tools, and a `vscode` user with `sudo`. Starting from `ubuntu:24.04` would lose those conveniences. |
| `RUN apt-get update && ... apt-get install ...` | Installs `sqlite3`, `dos2unix`, and `shellcheck`, which have no Feature. `update` and `install` share one `RUN` so a cached package index is never reused with a new package list. `--no-install-recommends` keeps the layer small; `DEBIAN_FRONTEND=noninteractive` prevents prompts; deleting `/var/lib/apt/lists` keeps the index out of the image. |
| `COPY certs/ ...` + `update-ca-certificates` | Adds every `*.crt` in `.devcontainer/certs/` to the OS trust store. It works when the folder holds no certificates. |
| `ENV REQUESTS_CA_BUNDLE` / `NODE_EXTRA_CA_CERTS` | Azure CLI (Python) and VS Code extensions (Node.js) bundle their own CA lists. These variables point them at the OS bundle, including your extra certificates. |
| `ARG IMAGE_GREETING` + `ENV HELLO_GREETING` | An `ARG` exists only while building. Copying it to an `ENV` bakes it into the image, so every process in the container can read it. |
| `COPY config/learning.conf ...` | Bakes a configuration file into `/etc/devcontainer-learning/`. Paths on the left are relative to the build context. |

**Order matters for caching.** Docker reuses a layer only if that instruction and
all earlier ones are unchanged. Slow, rarely-changing steps such as package
installs come first; frequently edited values come last. Feature layers are built
on top of the *final* Dockerfile layer, so any Dockerfile change also reruns the
Feature installers. Exercise 5 shows this.

`ARG` vs `ENV` vs `devcontainer.json` environment settings:

| Where | When it applies |
| --- | --- |
| Dockerfile `ARG` / `build.args` | Build time only, unless copied into an `ENV`. Visible in image history; never use it for secrets. |
| Dockerfile `ENV` | Baked into the image. Every process gets it, including `docker run` outside VS Code. |
| `containerEnv` in `devcontainer.json` | Set on the container when it is created. Overrides an image `ENV`; changing it needs a rebuild but reuses image layers. |
| `remoteEnv` in `devcontainer.json` | Only VS Code's server, terminals, and tasks. Can change without rebuilding the container. |

### Corporate proxies and root certificates

Many organisations inspect TLS traffic with a proxy that presents certificates
signed by an internal root CA. Without that CA, `apt-get`, `curl`, `dotnet
restore`, `az`, and VS Code extensions fail with certificate errors.

1. Get the **public** root CA certificate in PEM (Base-64) format from your IT
   or security team. Never use a private key.
2. Save it as `.devcontainer/certs/<name>.crt`.
3. Run **Dev Containers: Rebuild Container**.

The certificate step comes *before* `ENV`, config, and Features, so it is in
place for the later steps and for the Feature installers. For a certificate to
help the `apt-get` step itself, move the certificate section above the package
section. A proxy address can be passed with `build.args` such as `HTTP_PROXY` and
`HTTPS_PROXY`; Docker accepts those build arguments without declaring them.
Docker Desktop also has its own proxy settings.

Certificate files are ignored by Git in this repository. A public CA certificate
is not secret, but whether to commit it is a team policy decision.

### Running and debugging

[`launchSettings.json`](src/HelloDockerfile/Properties/launchSettings.json) is
shared by `dotnet run` and C# Dev Kit. Its `http` profile binds to
`http://0.0.0.0:8080`: all container interfaces, not an address to type in your
host browser. [`.vscode/launch.json`](.vscode/launch.json) provides the
**Debug HelloDockerfile** F5 configuration. Both inherit `HELLO_GREETING` from the
container.

### Lifecycle and persistence

The simplified sequence for this example is:

1. Build your Dockerfile, reusing cached layers where possible.
2. Run the Feature installers on top of it (also cached when possible).
3. Create/start a container and mount your workspace.
4. Run `postCreateCommand` to restore the project.
5. Connect VS Code and prepare the remote extensions.

| Action | Result |
| --- | --- |
| Edit source | Immediately updates the bind-mounted host file; no rebuild needed. Restart the app to run new code. |
| Edit the Dockerfile, `build.args`, or a copied file | Nothing changes until **Dev Containers: Rebuild Container**. |
| **Rebuild Container** | Rebuilds the image, reusing unchanged layers, then replaces the container. |
| **Rebuild Without Cache** | Rebuilds every layer from scratch. Slower; use it to pick up newer packages or rule out a stale cache. |
| `sudo apt-get install` in a terminal | Works until the container is replaced, then disappears. Put it in the Dockerfile instead. |

No Azure credentials or host Docker socket are mounted by this configuration.
If you choose to run `az login`, that state is lost when the container is
replaced. Never `COPY` credentials or secrets into an image: image layers and
build arguments are easy to inspect. Use **Dev Containers: Reopen Folder Locally**
to return to host development.

## 5. Five guided exercises

Do these in order after the quick start. They need no Azure subscription and
create no cloud resources. Exercises 2 to 5 each rebuild the container; a rebuild
that changes the Dockerfile also reruns the Feature installers, so expect each to
take a few minutes.

### Exercise 1: Find where each tool came from

**Goal:** Tell what the base image, your Dockerfile, and the Features each add.

1. Confirm the bottom-left remote indicator says **Dev Container**.
2. In the **container terminal**, run:

   ```bash
   whoami
   grep PRETTY_NAME /etc/os-release
   command -v git jq sqlite3 dos2unix shellcheck dotnet az bicep
   echo "$HELLO_GREETING"
   cat /etc/devcontainer-learning/learning.conf
   ls /usr/local/share/ca-certificates/
   ```

3. Match each result to its source:

   | Result | Source |
   | --- | --- |
   | `vscode`, Ubuntu 24.04, `git`, `jq` | Base image (`FROM` line) |
   | `sqlite3`, `dos2unix`, `shellcheck` | Dockerfile `RUN apt-get install` |
   | `HELLO_GREETING` | Dockerfile `ARG` + `ENV` |
   | `/etc/devcontainer-learning/learning.conf` | Dockerfile `COPY` |
   | `dotnet`, `az`, `bicep` | Features, installed after the Dockerfile |

4. Optional, in a **host terminal**, list the image layers:

   ```text
   docker ps --filter "label=devcontainer.local_folder" --format "{{.Image}}  {{.Names}}"
   docker history <image-from-the-first-column>
   ```

**Expected:** All commands resolve, `learning.conf` shows `config_version=1`, and
the certificate folder is empty because `certs/` contains only a README. In
`docker history`, the newest layers (top) belong to Features, then your
Dockerfile instructions, then the base image.

**Cleanup:** None; these commands only inspect the environment.

### Exercise 2: Install an OS package the right way

**Goal:** See why packages belong in the Dockerfile rather than a terminal.

1. Install ripgrep manually in the **container terminal**:

   ```bash
   sudo apt-get update && sudo apt-get install -y ripgrep
   rg --version
   ```

   It works, but only in this container.
2. Open [`.devcontainer/Dockerfile`](.devcontainer/Dockerfile). If `shellcheck`
   is already listed, remove that line and rebuild first. Then add
   `shellcheck` to the existing package list, keeping the backslashes and
   alphabetical order. The complete package installation should look like:

   ```dockerfile
   RUN apt-get update \
       && export DEBIAN_FRONTEND=noninteractive \
       && apt-get install -y --no-install-recommends \
           dos2unix \
           shellcheck \
           sqlite3 \
       && apt-get clean \
       && rm -rf /var/lib/apt/lists/*
   ```

3. Save, then run **Dev Containers: Rebuild Container**. Watch the log: the
   package layer rebuilds, and the Features after it reinstall.
4. In a **new container terminal**, run:

   ```bash
   command -v shellcheck && shellcheck --version
   command -v rg || echo "rg is gone: the manual install was lost"
   ```

**Expected:** `shellcheck` is available because it is part of the image
definition. `rg` is gone because it lived only in the replaced container. Every
teammate who rebuilds gets `shellcheck` too.

**Cleanup:** Leave `shellcheck` in the list to restore the default configuration.

### Exercise 3: Bake in a build argument and environment variable

**Goal:** Pass a value from `devcontainer.json` into the image and your app.

1. Run the API and confirm the current greeting:

   ```bash
   dotnet run --project src/HelloDockerfile/HelloDockerfile.csproj --launch-profile http
   ```

   In a second terminal, run `curl --fail http://localhost:8080/`, then stop the
   API with **Ctrl+C**.
2. In [`devcontainer.json`](.devcontainer/devcontainer.json), change the build
   argument:

   ```json
   "args": {
     "IMAGE_GREETING": "Hello from my own image build!"
   }
   ```

3. Save and run **Dev Containers: Rebuild Container**. Note that the package layer
   is `CACHED` in the log: it comes *before* `ARG`, so it was not rerun.
4. In a **new container terminal**, check the variable and rerun the API:

   ```bash
   echo "$HELLO_GREETING"
   dotnet run --project src/HelloDockerfile/HelloDockerfile.csproj --launch-profile http
   ```

   Refresh the browser via the **Ports** view, or `curl` from a second terminal.

**Expected:** The response is `{"message":"Hello from my own image build!"}`.
The C# code did not change; the image did. Editing `args` without rebuilding
would change nothing.

**Cleanup:** Stop the API. Restore
`"Hello from a Dockerfile-built dev container!"` and save. The next exercise's
rebuild applies it.

### Exercise 4: Trust a custom root certificate

**Goal:** Practise the corporate-CA workflow safely with a throwaway test CA.

> These test keys are for this exercise only. Never use them for anything else,
> and never commit them. `.ca-lab/` and certificate files are ignored by Git.

1. In the **container terminal**, create a test root CA and a `localhost` server
   certificate signed by it:

   ```bash
   mkdir -p .ca-lab && cd .ca-lab
   openssl req -x509 -newkey rsa:2048 -nodes -days 7 \
     -keyout test-root-ca.key -out test-root-ca.crt \
     -subj "/CN=Dev Container Learning Test Root CA" \
     -addext "basicConstraints=critical,CA:TRUE" \
     -addext "keyUsage=critical,keyCertSign,cRLSign"
   openssl req -newkey rsa:2048 -nodes \
     -keyout server.key -out server.csr -subj "/CN=localhost"
   printf 'subjectAltName=DNS:localhost\nextendedKeyUsage=serverAuth\n' > server.ext
   openssl x509 -req -in server.csr -days 7 \
     -CA test-root-ca.crt -CAkey test-root-ca.key -CAcreateserial \
     -extfile server.ext -out server.crt
   cd ..
   ```

2. Start a small HTTPS server with that certificate, and leave it running:

   ```bash
   openssl s_server -accept 8443 -www -cert .ca-lab/server.crt -key .ca-lab/server.key
   ```

3. In a **second container terminal**, request it:

   ```bash
   curl --fail https://localhost:8443/
   ```

   This fails with `unable to get local issuer certificate`. That is the same
   error a corporate proxy causes. Stop the server with **Ctrl+C**.
4. Copy only the **public** CA certificate into the build context:

   ```bash
   cp .ca-lab/test-root-ca.crt .devcontainer/certs/
   ```

5. Run **Dev Containers: Rebuild Container**. In a **new container terminal**,
   start the server again, and in a **second terminal** repeat the request:

   ```bash
   openssl s_server -accept 8443 -www -cert .ca-lab/server.crt -key .ca-lab/server.key
   ```

   ```bash
   ls /usr/local/share/ca-certificates/
   curl --fail --silent --show-error -o /dev/null -w '%{http_code}\n' https://localhost:8443/
   ```

**Expected:** `test-root-ca.crt` is in the trust store, and `curl` now succeeds
without `-k`/`--insecure` and prints the HTTP status `200`.
`.ca-lab/` survived the rebuild because it is in the workspace, while trust came
from the image. Tools that use the OS store, including `dotnet`, Azure CLI with
`REQUESTS_CA_BUNDLE`, and extensions with `NODE_EXTRA_CA_CERTS`, now trust the
same CA.

**Cleanup:** Stop the server. Remove the test CA and keys, then rebuild so the
image no longer trusts the test CA:

```bash
rm .devcontainer/certs/test-root-ca.crt
rm -r .ca-lab
```

Run **Dev Containers: Rebuild Container**, and check that
`ls /usr/local/share/ca-certificates/` is empty again.

### Exercise 5: Build context, copied files, and the layer cache

**Goal:** Understand what triggers a rebuild, which steps rerun, and why.

1. Edit [`.devcontainer/config/learning.conf`](.devcontainer/config/learning.conf)
   and change `config_version=1` to `config_version=2`. Save.
2. In the **container terminal**, check the baked-in copy:

   ```bash
   cat /etc/devcontainer-learning/learning.conf
   ```

   It still shows `config_version=1`. Files copied by the Dockerfile are a
   snapshot taken at build time; unlike the workspace, they are not live.
3. Run **Dev Containers: Rebuild Container** and select **show log**. Look for
   `CACHED` beside the `apt-get` and certificate steps: only the last `COPY`
   and the Feature layers above it run again.
4. In a **new container terminal**, confirm the new value:

   ```bash
   cat /etc/devcontainer-learning/learning.conf
   ```

5. Read, but do not add, this line:

   ```dockerfile
   COPY ../src /src
   ```

   It would fail with an error such as `"/src": not found`: `src/` is outside the
   `.devcontainer/` build context. Source code reaches the container through the
   workspace mount instead.
6. Optional: run **Dev Containers: Rebuild Without Cache**. Every step, including
   `apt-get`, runs again. Use this to pick up
   newer package versions or rule out a stale cache.

**Expected:** The container shows `config_version=2` after the rebuild, and the
log shows earlier layers reused. Putting rarely-changed steps first keeps
rebuilds fast; anything that changes the Dockerfile output also reruns Features,
so keep edits there deliberate.

**Cleanup:** Restore `config_version=1` and remove any leftover exercise changes,
such as `shellcheck` or a changed `IMAGE_GREETING`. Rebuild once more to return to
the original image. Confirm with:

```bash
git status --short
```

Nothing should be listed.

## 6. Troubleshooting

| Symptom | Check |
| --- | --- |
| Cannot connect to Docker / missing Linux engine pipe | Start Docker Desktop on the host and select Linux containers. Check `docker version` in a host terminal. |
| Build fails at a Dockerfile step | Open **Dev Containers: Show Container Log**, find the first error, and fix the Dockerfile. Choose **Edit devcontainer.json Locally** if prompted, then **Rebuild**. |
| `COPY failed` / `not found` | `COPY` paths are relative to `build.context` (`.devcontainer/`). Files outside it cannot be copied. |
| `apt-get` fails with `Unable to locate package` | Check the package name for Ubuntu 24.04 and that `apt-get update` is in the same `RUN` instruction. |
| Certificate errors during build or restore | Follow [Corporate proxies and root certificates](#corporate-proxies-and-root-certificates). Use PEM format, a `.crt` extension, and the **root** CA, then rebuild. |
| Certificate added, but a tool still fails | Rebuild, then check `ls /usr/local/share/ca-certificates/`. Some tools have their own CA settings; check that tool's documentation. |
| A Dockerfile or `build.args` change seems ignored | Use **Dev Containers: Rebuild Container**, not reload/reopen. Try **Rebuild Without Cache** if you suspect a stale layer. |
| Build is slow after every small change | Any Dockerfile change reruns Features. Group changes, and keep stable steps near the top. |
| `/bin/sh^M: bad interpreter` from a copied script | The script has Windows line endings. This repository's `.gitattributes` keeps LF; `dos2unix <file>` fixes an existing file. |
| Browser cannot connect | Start the API, then use the Ports view's actual forwarded address. Do not browse to `0.0.0.0`. |
| Port already in use inside container | Stop the API terminal with Ctrl+C or its debug session with Shift+F5 before launching another. |
| F5 configuration is unavailable or breakpoint is unbound | Check C# Dev Kit is installed in the container, let project loading finish, and select **Debug HelloDockerfile**. |

## Official references

- [Create a Dev Container: Dockerfile](https://code.visualstudio.com/docs/devcontainers/create-dev-container#_dockerfile)
- [Dev Container configuration reference: image or Dockerfile properties](https://containers.dev/implementors/json_reference/#-image-or-dockerfile-specific-properties-)
- [Dev Container Features](https://containers.dev/features)
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [Dockerfile best practices](https://docs.docker.com/build/building/best-practices/)
- [Docker build cache](https://docs.docker.com/build/cache/)
- [Azure CLI behind a proxy](https://learn.microsoft.com/cli/azure/use-azure-cli-successfully-troubleshooting#work-behind-a-proxy)
- [.NET Feature options](https://github.com/devcontainers/features/tree/main/src/dotnet)
- [Azure CLI Feature options (including Bicep)](https://github.com/devcontainers/features/tree/main/src/azure-cli)
