# Development Guide

## Repository Structure and Naming Conventions

## Resources

### Building Debian Packages

* <https://wiki.debian.org/DebianRepository/Setup>
* <https://earthly.dev/blog/creating-and-hosting-your-own-deb-packages-and-apt-repo/>

### Package Name Conventions

#### Archive Package Names

```plain
<package-name>_<version>_<os>_<architecture>
```

```plain
hello-world_1.2.3_linux_amd64.tar.gz
hello-world_1.2.3_linux_arm64.tar.gz
hello-world_1.2.3_windows_amd64.zip
```

#### RPM and DEB Package Names

```plain
<package-name>_<version>-<release-number>_<architecture>
```

For example:

```plain
hello-world_1.2.3-1_amd64   # DEB
hello-world_1.2.3-1_arm64   # DEB

hello-world_1.2.3-1_x86_64  # RPM
hello-world_1.2.3-1_aarch64 # RPM
```

## AWS Configuration

I'm serving the repositories from an S3 bucket behind CloudFront.

Lambda@Edge functions:

* Pretty URLs
* 403to404
