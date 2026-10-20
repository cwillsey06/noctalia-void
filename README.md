# noctalia-void

[![build](https://github.com/cwillsey06/noctalia-void/actions/workflows/build.yml/badge.svg)](https://github.com/cwillsey06/noctalia-void/actions/workflows/build.yml)

An **unofficial** Void repository for the `noctalia`, `noctalia-greeter`, `umbriel`, and `xdg-desktop-portal-umbriel` projects. This source is not endorsed by Noctalia's developer organisation, nor Void...nor anyone! Use at your own risk.

See **official** docs, examples, and more for Noctalia @ [noctalia.dev](https://noctalia.dev/) :)


## Package install

Create a file `/etc/xbps.d/20-noctalia.conf`, with the following content:
```
repository=https://github.com/cwillsey06/noctalia-void/releases/download/repo
```

Then simply `xbps-install -S <pkgname>`, and accept the signature, you don't have to do anything else but your occasional `xbps-install -Su` to get updates.

You could also **install the packages manually**, go to [releases](https://github.com/cwillsey06/noctalia-void/releases/latest), and download an `.xbps` file. Place it into an empty directory, then edit and run the following commands:
```
$ xbps-rindex -a <pkgname>-<ver>_<rev>.<arch>.xbps
# xbps-install -R "$PWD" <pkgname>
```

Noctalia and it's greeter get package updates every time a new GitHub release comes out, as well as bi-weekly... bi-monthly?? —**the 1st and 15th**. Umbriel and the desktop portal are yet to be "released", so similarly, on the first and fifteenth, they get re-built and re-published from the latest main branch commit on their respective repositories.


## Build locally

Clone this repo somewhere, and `cd` into it. First, **review** the following script, then run it:
```
$ ./scripts/local-build.sh -c <pkgnames>
```
(or try `./scripts/local-build.sh -h` for more options)


## Note for noctalia-greeter

Either method you choose to install by, `noctalia-greeter` has it's own special post-install setup, read more about that [here](srcpkgs/noctalia-greeter/files/README.voidlinux).


## License

For the templates, scripts, et cetera associated with exclusively this repository—they're all Unlicense-d, public-domain. See [LICENSE](LICENSE) for more information.


## Credits

[noctalia.dev](https://noctalia.dev/), [github.com/noctalia-dev](https://github.com/noctalia-dev/) of course :)

Thank you to [index-0/librewolf-void](https://github.com/index-0/librewolf-void) for a great example on how to make this stuff work, as well as a reference on how the [build](#build-locally) and [install](#package-install) sections should look. It's also a great resource in general, LibreWolf wouldn't be my one and only beloved browser without it and it's contributors. :) 

I used Claude Opus 5.5 to create the templates, build scripts, and action stuff. I did write this README myself, however.

