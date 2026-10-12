# What is this?
A simple Ubuntu package for BerserkMC that contains a script which downloads and installs the upstream MultiMC build on Ubuntu based systems.

It contains a `.desktop` file, an icon, and a simple script that does the heavy lifting.

> **Note:** BerserkMC has no standalone Linux artifact yet, so the wrapper
> installed by this package still deploys the upstream MultiMC build. Only the
> install location and the visible branding are BerserkMC. Update `run.sh` to
> point at a BerserkMC build once one exists.

This is also the source for the files in the [RPM package](../rpm). If you rename, create or delete files here, you'll likely also have to update the RPM spec file there.

# How to build this?
You need dpkg utils. Rename the `berserkmc` folder to `berserkmc_1.6-1` and then run:
```
fakeroot dpkg-deb --build berserkmc_1.6-1
```

Replace the version with whatever is appropriate.
