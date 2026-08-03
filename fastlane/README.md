fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

### validate_metadata

```sh
[bundle exec] fastlane validate_metadata
```

Check fastlane/metadata against App Store Connect limits, without uploading

### setup_app_store_connect_api_key

```sh
[bundle exec] fastlane setup_app_store_connect_api_key
```

Set up the App Store Connect API key

### create_ci_keychain

```sh
[bundle exec] fastlane create_ci_keychain
```

Create the CI keychain

----


## iOS

### ios release_match

```sh
[bundle exec] fastlane ios release_match
```

Match App Store provisioning profiles

### ios release_build

```sh
[bundle exec] fastlane ios release_build
```

Build the app for release

### ios release_upload

```sh
[bundle exec] fastlane ios release_upload
```

Publish the app to TestFlight

### ios deliver_metadata

```sh
[bundle exec] fastlane ios deliver_metadata
```

Update the App Store metadata. Run validate_metadata first to check it without uploading.

----


## Mac

### mac release_match

```sh
[bundle exec] fastlane mac release_match
```

Match App Store provisioning profiles for macOS

### mac release_build

```sh
[bundle exec] fastlane mac release_build
```

Build the app for macOS release

### mac deliver_metadata

```sh
[bundle exec] fastlane mac deliver_metadata
```

Update the App Store metadata for macOS. Run validate_metadata first to check it without uploading.

### mac release_upload

```sh
[bundle exec] fastlane mac release_upload
```

Publish the macOS app to App Store Connect

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
