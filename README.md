## About

This is a fork of **Mastonaut** by @brunophilipe, whose original marketing page you can still look at [here](https://mastonaut.app). His latest version 1.3.9 can still be [installed from the App Store](https://apps.apple.com/us/app/mastonaut/id1450757574).

### Some features since 1.3.9

(As of 1.6.0.)

#### Accessibility

* Assorted accessibility improvements

#### Composing

* Edit your toots
* Autocomplete for hashtags (1.3.9 already had autocomplete for user names)

#### Notifications

* Filter notifications by type (for example, to only see mentions)

#### Search

* Search for (already known) toots by text or their URL

#### Timeline

* Pull to refresh
* View a list as a column
* View your favorites or bookmarks as a column

#### Viewing

* See if a toot has been edited, and view previous versions

## 👩🏽‍💻 End Users: Install

To use it, you just want to [download 1.6 here](https://github.com/chucker/Mastonaut/releases/download/app-1.6.0/Mastonaut-1.6.0.zip).

## 🗺️ Roadmap

This is purely a hobbyist effort, so I can't really promise anything. I try to do a new release every month or two.

## 👩🏻‍🌾 Developers: Build

These are instructions for if you want to tinker with the code.

The following instructions assume Xcode 14.1 on macOS 13.0.1.

### Setup

- Copy the file `userspecific.template.xcconfig` to `userspecific.xcconfig`, and open that file.

- Set `MASTONAUT_BUNDLE_ID_BASE` to a bundle ID for the app that works with your Apple ID.

- Enter your Team ID instead of the `xxxxxxxxxx` next to `DEVELOPMENT_TEAM` (It looks something like `74J34U3R6X`).

- **Do not check in your changes to `userspecific.xcconfig`!**

That should be it.

### Bundle IDs

The bundle ID _base_ is used because Mastonaut consists of multiple projects, which use an app group to share information. Given a `MASTONAUT_BUNDLE_ID_BASE` of `com.example.mastonaut` and a `DEVELOPMENT_TEAM` of `ABCDEFGH`:

- the main app will be `com.example.mastonaut.mac`
- the macOS Sharing extension will be `com.example.mastonaut.mac.QuickToot`
- the Core Data database shared by the two above will be stored in `~/Library/Group Containers/ABCDEFGH.com.example.mastonaut/Mastonaut/Mastonaut.sqlite`
- Keychain credentials will be prefixed `ABCDEFGH.com.example.mastonaut.keychain`

### Acknowledgments

Most of the **Acknowledgments** in the about box are
auto-generated from Cocoapods dependencies. For this, you
need to have the `cocoapods-acknowledgements` plug-in
installed, and then just run `pod install`.

Additional dependencies come via SwiftPM and Git submodules, and those get added manually in code.

### Pitfalls

- Make sure `MastodonKit` is fetched _as a git submodule_. (For example, Xcode's git clone functionality seems to not do this!) This appears to be a
custom fork called 3.0 that's significantly different from the public MastodonKit. So don't try to change the project to pull the regular MastodonKit using
CocoaPods.

- The `.xcconfig` will auto-append `.mac` and other suffixes to the `MASTONAUT_BUNDLE_ID_BASE`, so you should pick something like
`com.example.mastonaut` (replacing `com.example` with whatever reverse domain name you have set up for your account).

- If you don't know your Team ID, go into _Signing & Capabilities_ in your project and select your team, then your UI will show it under 'App Groups'.
Then revert the project file so it will use the setting from the `xcconfig` and you don't have a lurking change in your checkout.

### Project Structure

The main application is **Mastonaut**. It should be developed within `Mastonaut.xcworkspace`.

**QuickToot** is a macOS app extension, specifically for sharing.

QuickToot and Mastonaut use **CoreTootin** as a common library. GUI code that's required by both belongs here.

The underlying API client is largely implemented in (a custom fork of) **MastodonKit**, which is referenced as a git submodule.

- If you're using a personal developer ID and get an error like `Personal development teams, including "Your Name Here", do not support the Push
Notifications capability.`, you may have to go _Signing and Capabilities_ and delete the "Push Notifications" capability by clicking the little
trash can next to it. **Do not check in this change.**
