# TillerPrinter

[![CI Status](http://img.shields.io/travis/Felix Carrard/TillerPrinter.svg?style=flat)](https://travis-ci.org/Felix Carrard/TillerPrinter)
[![Version](https://img.shields.io/cocoapods/v/TillerPrinter.svg?style=flat)](http://cocoapods.org/pods/TillerPrinter)
[![License](https://img.shields.io/cocoapods/l/TillerPrinter.svg?style=flat)](http://cocoapods.org/pods/TillerPrinter)
[![Platform](https://img.shields.io/cocoapods/p/TillerPrinter.svg?style=flat)](http://cocoapods.org/pods/TillerPrinter)

TillerPrinter is an internal Abstraction of EpsonPrinters librairies with a simple Template solution for generating tickets

- [Development & Contributing](#development-&-contributing)
- [Requirements](#requirements)
- [Installation](#installation)
- [License](#license)
- [About Tiller Store](#about-tiller-store)

##  Development & Contributing

There's two way to work on the development of the project, writing tests or building the example Application :

1. Fetch the repository > run `Pod Install` > open **TillerPrinter.xcworkspace**
2. Fetch TillerPrinter as a developments Pods in your `Podfile` or `Podfile.local` as :

```
pod 'TillerPrinter', :path => "/Users/Developer/Components/TillerPrinterPath"
```

## Requirements

- iOS 10.1+
- Xcode 8.3+
- Swift 3.2+

## Installation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

> CocoaPods 1.1+ is required to build TillerPrinter 0.1+.

To integrate TillerPrinter into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/tillersystems/TillerPodSpecRepo.git'
platform :ios, '10.1'
use_frameworks!

target '<Your Target Name>' do
pod 'TillerPrinter', '~> 0.1.0'
end
```

Then, run the following command:

```bash
$ pod install
```

## License

TillerPrinter is available under the MIT license. See the LICENSE file for more info.

## About Tiller Printer

TillerPrinter was built by [Felix Carrard][author], is maintained by [Tillersystems R&D Team][tillersystems].

[author]:              https://github.com/carrarF
[tillersystems]:    https://github.com/orgs/tillersystems/people
