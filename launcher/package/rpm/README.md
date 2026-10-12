# What is this?
A simple RPM package for BerserkMC that contains a script which downloads and installs the upstream MultiMC build on Red Hat based systems.

It contains a `.desktop` file, a `.metainfo.xml` file, an icon, and a simple script that does the heavy lifting.

> **Note:** BerserkMC has no standalone Linux artifact yet, so the wrapper
> installed by this package still deploys the upstream MultiMC build. Only the
> install location and the visible branding are BerserkMC.

# How to build this?
You need the `rpm-build` package. Switch into this directory, then run:
```
rpmbuild --build-in-place -bb BerserkMC.spec
```

Replace the version with whatever is appropriate.
