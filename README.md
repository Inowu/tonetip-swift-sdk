# ToneTip SDK (iOS)

ToneTip SDK is a Swift library that allows you to decode [ToneTips](https://tonetip.com/why-tonetip/#how-it-works) from audio sources. It is ideal for music apps, podcast platforms, or other audio-related projects.

## Installation

To install the SDK, use CocoaPods:

```swift
pod 'tonetip_ios', '~> 1.0.4'
```

## API Key Requirement

To use the SDK, you must generate an API Key from the [ToneTip Dashboard](https://tt.media). The API Key is required, and the SDK will not function without it. Note that access to the API is a paid service.

Configure your key early in the app launch:

```swift
import Tonetip_ios

// In AppDelegate or before using the SDK:
ToneTipConfig.apiKey = "YOUR_API_KEY"
ToneTipConfig.isSandbox = true  // Use the testing environment
```

## Basic Usage

Below is a basic example of how to use ToneTip SDK in a Swift project with SwiftUI. This demonstrates the new start(completion:) API which ensures audio session, engine, and decoder initialize atomically before listening begins.

```swift
import SwiftUI
import Tonetip_ios

class AudioManager: NSObject, ObservableObject, TonetipDelegate {
    private var tonetipManager: TonetipManager?

    @Published var isListening = false
    @Published var detectedUarc: String = "N/A"

    override init() {
        super.init()
        ToneTipConfig.apiKey = "YOUR_API_KEY"
        ToneTipConfig.isSandbox = true

        let manager = TonetipManager()
        manager.delegate = self
        self.tonetipManager = manager
    }

    func toggleListening() {
        guard let manager = tonetipManager else { return }

        if isListening {
            manager.stopListening()
            isListening = false
        } else {
            manager.startListening { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Failed to start listener: \(error)")
                    } else {
                        print("✅ TonetipManager active")
                        self.isListening = true
                    }
                }
            }
        }
    }

    // MARK: - TonetipDelegate
    func drawnTone(uarc: String, frequency: Int) {
        DispatchQueue.main.async {
            self.detectedUarc = "🔊 \(uarc) @ \(frequency)Hz"
            print("🔊 UARC detected: \(uarc) at \(frequency)Hz")
        }
    }
}
```

## Configuration Options

SDK configuration is done via ToneTipConfig:

```swift
ToneTipConfig.apiKey = "YOUR_API_KEY"
ToneTipConfig.isSandbox = true  // Use the testing environment
```

## Compatibility

ToneTip SDK is compatible with:

- iOS 14.0 and above
- Swift 5.x

## Full Documentation

For more details about available methods and configurations, visit: [tt.media/docs](https://tt.media/docs).

