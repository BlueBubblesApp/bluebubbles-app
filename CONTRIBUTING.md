# Contribution Guide

We encourage all contributions to this project! All we ask are you follow these simple rules when contributing:

* Write clean code
* Comment your code
* Follow [dart doc guidelines](https://dart.dev/guides/language/effective-dart)

## Pre-requisites

Please make sure you have completed the following pre-requisites:

* Install Git: [download](https://git-scm.com/downloads)
* Install Java: [download](https://www.oracle.com/java/technologies/javase/javase-jdk8-downloads.html)
* Install Flutter: [guide/download](https://flutter.dev/docs/get-started/install)
* Install Android Studio [download](https://developer.android.com/studio)
    - Also install the Flutter & Dart Plugins via the Plugin Manager
    - If you wish you use a virtual Android device, install one via the AVD Manager
    - Install Command Line Tools via the SDK Tools interface
* Install a code editor (if you don't want to use Android Studio). Here is my preferred editor:
    - [Visual Studio Code](https://code.visualstudio.com/download)

Once you have a code editor installed, remember to install all of the required plugins/extensions such as the following:

* Dart
* Flutter
* Intellisense/Intellicode

## Forking the Repository

In order to start contributing, follow these steps:

1. Create a GitHub account
2. Fork the `BlueBubbles-Android-App` repository: [here](https://github.com/BlueBubblesApp/BlueBubbles-Android-App)
    * Click the fork button at the top right of your brwoser
3. On your projects folder (or any preferred folder), clone your forked repository:
    * HTTPS: `git clone https://github.com/BlueBubblesApp/BlueBubbles-Android-App.git`
    * SSH: `git clone git@github.com:BlueBubblesApp/BlueBubbles-Android-App.git`
4. Set the upstream to our main repo (this will allow you to pull official changes)
    * `git remote add upstream git@github.com:BlueBubblesApp/BlueBubbles-Android-App.git`
5. Fetch all the required branches/code
    * `git fetch`
    * `git fetch upstream`
6. Pull the latest changes, or a specific branch you want to start from
    * Pull code from the main repository's master branch: `git pull upstream master`
    * Checkout a specific branch: `git checkout upstream <name of branch>`

## Picking an Issue

If you are working on something that does not have an issue created for it yet, please create an issue for it so we can easily track it. Otherwise, check out our issues page [here](https://github.com/BlueBubblesApp/BlueBubbles-Android-App/issues), and here are some tips:

* I have labelled issues by difficulty. You can add `label:"Difficulty: Easy"` to the query to filter. The options are Easy, Medium, or Hard.
    - Some issues have 2 Difficulty labels. This just means they are somewhere in between the two difficulties.
* I have also labelled issues by if they are bugs (`bug`)or feature requests (`enhancement`)
* If you are new to Flutter/Dart, you can filter on issues with the `label:"good first issue"`
    - Though, you may find issues with similar difficulty by just filtering on the `Difficulty: Easy` label

## Committing Code

When you are ready to work on the code, follow these steps.

1. Create your own branch
    * `git checkout -b <your name>/<feature|bug>/<short descriptor>`
    * Example: `git checkout -b zach/feature/improved-animations`
2. Make your code changes :)
3. Stage your changes to the commit using a code-editor plugin, or Git directly
    * Stage a specific file: `git add <file name>`
    * Stage all changes: `git add -A`
4. Commit your changes
    * `git commit -m "<Description of your changes>"`
5. Push your changes to your forked repository
    * `git push origin <your branch name>`

## Submitting a Pull-Request

Once you have made all your changes, follow these instructions:

1. Login to GitHub's website
2. Go to your forked `BlueBubbles-Android-App` repository
3. Go to the `Pull requests` tab
4. Create a new Pull request, merging your changes into the main `development` branch
5. Please include the following information with your pull request:
    * The problem
    * What your code solves
    * How you fixed it
6. Once submitted, your changes will be reviewed, and hopefully committed into the master branch!

## Getting GIF Keyboard Support

One feature that is not yet native in the Dart/Flutter languages is the ability to use a keyboard to send an image to an app. For example, the ability to use the GIF keyboard in Google's Keyboard to send a GIF. There is currently an open GitHub issue for the Flutter team to implement this feature. However, as of writing this, it is not supported. You can follow the progress of the feature here:

[GitHub Issue - Image keyboard support](https://github.com/flutter/flutter/issues/20796)

That said, we have modified the Flutter engine and Flutter framework to support GIF insertion from a keyboard. We have forked the Flutter engine repository, and the flutter framework repository to integrate this feature for BlueBubbles. You can view the forked repositories here:

* [Flutter Engine](https://github.com/BlueBubblesApp/engine)
* [Flutter Framework](https://github.com/BlueBubblesApp/flutter)

If you would like to get this feature in your own personal builds, you have 2 options. The first option is to build your own Flutter Engine with the GIF Keyboard changes. The second option is to download my pre-built Flutter Engine with the changes already made to the Flutter SDK, `v1.22.4`

Once you have a custom Flutter Engine built, you will be able to use it when using `flutter run`, `flutter build`, etc. There are 2 additional CLI params/flags you need to use to reference the custom Flutter Engine:

* `--local-engine`
    - This specifies which of the engines to use (debug, profile, release, etc.)
* `--local-engine-src-path`
    - This specifies the path to the built Flutter Engine

You can use the flags above, like so: `flutter run --debug --local-engine=android_debug_unopt --local-engine-src-path=/path/to/your/extracted/engine/src`

### Using my Pre-built Flutter Engine (Optional)

This method will only work if you are running Ubuntu 18.04. Building your own custom Flutter Engine only works on a few Operating Systems. Ubuntu 18.04 is one of those, and newer versions of Ubuntu are not supported as of writing this. I am unsure if this build will work on other Unix flavors, that is for you to try and find out! If you want a sure-fire way to use the custom engine, just use Ubuntu 18.04

**Flutter Engine Download**: https://mega.nz/file/sxJXnQoR#XNwRm7aDdqV7UTxKisiFflI2fWur4Hb2S9Ud2BwzNcg

Download the .zip file above and extract it somewhere. The location doesn't really matter, as long as you can reference it when you add the additional CLI params/flags like above

### Building your own Flutter Engine (Optional)

If you would like to compile your own engine to get GIF insertion, you can via Google's official guide, which can take a few hours to complete. You can find a guide on how to setup a Flutter development environment here:

[Setting up the Engine development environment](https://github.com/flutter/flutter/wiki/Setting-up-the-Engine-development-environment)

Make sure to use the BlueBubbles Flutter Engine repository listed above when cloning from Git (using `gclient sync`)

### Modifying the Flutter Framework

Once the Flutter Engine is built, you will also need to make similar changes in the Flutter Framework (SDK) so that you can actually utilize the new `onContentCommitted` hooks. Luckily, we have done most of the work for you. Simply checkout the BlueBubbles Flutter Framework repository (master branch) and use that as your Flutter SDK (make sure to add any environmental references to the bin path)

### Building a "release" build

Here is how you can build a "release" build. A build that is optimized and has no extra debugging or profiling tools. This type of build will run the smoothest for you. All you have to do is run the following:

**ARM Devices**: `flutter build apk --release --split-per-abi --local-engine=android_release --local-engine-src-path=/path/to/your/extracted/engine/src`

**ARM x64 Devices**: `flutter build apk --release --split-per-abi --local-engine=android_release_arm64 --target-platform=android-arm64 --local-engine-src-path=/path/to/your/extracted/engine/src`
