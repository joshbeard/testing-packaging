# TODO

## First

* [x] Produce artifacts (tar.gz, zip) of OS/architecture-specific packages
    * [x] Validation
    * [ ] TODO: contains README unexpectedly (maybe bundle main readme and license)
* [x] GPG signed
* [x] Build an RPM package
    * [x] Validation
* [x] Build a DEB package
    * [x] Validation
* [x] Provide an Arch Linux `PKGBUILD`
    * [ ] Validation
* [x] Upload the artifacts to S3
    * [x] Validation

## Second

* Can package repo metadata be updated without the files available locally?
    * Can we sync the metadata files from s3 in ci/cd and update them with the
      new packages while keeping the existing packages in the database (but not
      locally available in ci/cd)?
    * If not, persistent storage.
        * run the CI job on a private runner with persistent storage (home +
          nfs or a container with?)

* [x] Produce an RPM repository on S3
    * [x] Verify
* [x] Provide a DEB repository on S3
    * [x] Verify
* [ ] Provide a Homebrew Cask repository
    * [ ] Verify
* [x] Arch AUR
    * [x] Verify
* [x] Docker image
    * [x] Publish to Docker Hub
    * [x] Publish to ghcr.io

## Third

* [~] RPM repository GPG
  * [x] Verify
* [~] DEB repository GPG
  * [ ] Verify

* Publish to GitHub with GoReleaser - <https://goreleaser.com/scm/github/>
* Separate GoReleaser build from publish (wait for tests)

## Fourth

* [x] Directory indexes
  * [x] s3/cloudfront default indexes (index.html)
* [ ] Serve install script for curl/wget by default for root request
* [ ] Changelogs
* [ ] Release pipeline/workflow
* [ ] Invalidate CloudFront cache
* [~] Tests
    * Local web service serving `dist/stage/`
    * Test in Docker container
* [ ] Backups/Replication

## Future

* [ ] Submission to Arch community repo
* [ ] Submission to Homebrew main repo

## Other Ideas

* [x] Lambda@Edge function for serving directory listings?
    * Going with static [web-indexer](https://github.com/joshbeard/web-indexer) for now.
* [ ] FreeBSD port and package
* [ ] OpenBSD port and package
