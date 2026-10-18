<p align="center">
  <img src="branding/logo.png" alt="BerserkMC logo" width="128"/>
</p>

BerserkMC
=========

BerserkMC is a custom launcher for Minecraft focused on predictability, long
term stability and simplicity, fork of the MultiMC project.

> **Offline profiles + Microsoft accounts.** Profiles are either local offline
> accounts (player name only) or Microsoft accounts added with the QR /
> device-code sign-in. See [Accounts](#accounts).

This project is an independent fork. It is **not** affiliated with or endorsed
by the MultiMC project.

## Accounts

Two kinds of accounts are supported:

- **Offline profile** — a player name only, no login. Works in singleplayer, on
  LAN, and on servers with `online-mode=false` (the server accepts the offline
  UUID derived from the player name). It does **not** work on servers with
  `online-mode=true` (most public servers): the server asks Mojang's session
  server to verify the join token, and an offline profile has no token. This is
  a server-side check and cannot be worked around from the launcher.
- **Microsoft account** — added from the Comptes page with the QR code /
  link device-code flow. It launches the game online, so it works on
  `online-mode=true` servers.

The shortcut in the profile menu only ever creates offline profiles; Microsoft
accounts are added from the Comptes page.

## Building

Build instructions live in [BUILD.md](BUILD.md). BerserkMC targets Qt 5.15 with
the QML UI; the tested Windows toolchain is MSYS2 mingw-w64 + Qt 5 + Ninja.

## Translations

Translations can be contributed via the upstream Crowdin project. Avoid opening
pull requests that modify the translations repository directly.

## License

Copyright &copy; 2013-2022 MultiMC Contributors (upstream).

Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this program except in compliance with the License. You may obtain a copy of the
License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.
See [COPYING.md](COPYING.md) for the full text and third-party notices.

## Forking / redistributing / custom builds policy

The upstream project keeps the Launcher open source under the Apache license so
that the source can be audited. The license gives you access to the source code,
but not:

- The name, logo and other branding.
- The API tokens required to talk to the services the launcher depends on.

Because of the nature of the agreements required to interact with the Microsoft
identity platform, the upstream source has been debranded and builds without a
product name by default. You must provide your own branding if you want to
distribute your own builds, and register your own app on Azure to handle
Microsoft account logins.

If you fork the project, a mention of its origins in the About dialog and the
license is acceptable. However, it should be abundantly clear that the project
is a fork *without* implying any endorsement by the MultiMC project.
