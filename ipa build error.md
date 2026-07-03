Run flutter build ios \
  
Warning: Building for device with codesigning disabled. You will have to manually codesign before deploying to device.
Building com.dirxplore3.rakib.dirxplore3.torrentflow for device (ios-release)...
Adding Swift Package Manager integration...                        12.1s
The following plugins do not support Swift Package Manager for ios:
  - device_info_plus
This will become an error in a future version of Flutter. Please contact the plugin maintainers to request Swift Package Manager adoption.
Running pod install...                                           1,426ms
Running Xcode build...                                          
Xcode build done.                                           59.8s
Failed to build iOS app
Swift Compiler Error (Xcode): Value of type 'any FlutterImplicitEngineBridge' has no member 'binaryMessenger'
/Users/runner/work/Torrentflow1/Torrentflow1/ios/Runner/AppDelegate.swift:37:36
Encountered error while building for device.
Error: Process completed with exit code 1.