# ToneTip SDK (iOS)

ToneTip SDK is a Swift library that allows you to decode [ToneTips](https://tonetip.com/why-tonetip/#how-it-works) from audio sources. It is ideal for music apps, podcast platforms, or other audio-related projects.

## Installation

To install the SDK, use CocoaPods:

```swift
pod 'tonetip_ios', '~> 1.0.0'
```

## API Key Requirement

To use the SDK, you must generate an API Key from the [ToneTip Dashboard](https://tt.media). The API Key is required, and the SDK will not function without it. Note that access to the API is a paid service.

## Basic Usage

Below is a basic example of how to use ToneTip SDK in a Swift project with SwiftUI:

```swift
import Foundation
import Tonetip_ios

class AudioManager: NSObject, ObservableObject, TonetipDelegate {
    private var tonetipManager: TonetipManager?
    
    @Published var isListening = false
    @Published var detectedUarc: String = "N/A"
    
    override init() {
        super.init()
        ToneTipConfig.apiKey = "YOUR_API_KEY"
        ToneTipConfig.isSandbox = true
        
        tonetipManager = TonetipManager()
        tonetipManager?.delegate = self
    }
    
    func toggleListening() {
        if isListening {
            tonetipManager?.stopListening()
            isListening = false
        } else {
            tonetipManager?.startListening()
            isListening = true
        }
    }
    
    func drawnTone(uarc: String, frequency: Int) {
        DispatchQueue.main.async {
            self.detectedUarc = "🔊 \(uarc) @ \(frequency)Hz"
            print("🔊 UARC Detected at \(frequency)Hz: \(uarc)")
        }
    }
}
```

## Compatibility

ToneTip SDK is compatible with:

- iOS 14.0 and above
- Swift 5.x

## Configuration Options

SDK configuration is done via `ToneTipConfig`:

```swift
ToneTipConfig.apiKey = "YOUR_API_KEY"
ToneTipConfig.isSandbox = true // Use the testing environment
```

## Available Methods

### `TonetipManager`

- **`startListening()`**: Starts audio listening.
- **`stopListening()`**: Stops audio listening.

### `TonetipDelegate`

- **`drawnTone(uarc: String, frequency: Int)`**: Delegate method triggered when a ToneTip is detected. Returns the UARC code and detected frequency.

## Full Documentation

For more details about available methods and configurations, visit: [tt.media/docs](https://tt.media/docs).

