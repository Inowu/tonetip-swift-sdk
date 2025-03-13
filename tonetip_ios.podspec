Pod::Spec.new do |s|
  s.name         = 'tonetip_ios'
  s.version      = '1.0.1'
  s.summary      = 'Library for decoding and sending ToneTip telemetry.'
  s.description  = <<-DESC
tonetip_ios is a robust, high-performance library designed for decoding and sending ToneTip telemetry on iOS devices. It enables developers to efficiently process telemetry data from ToneTip devices, ensuring secure and reliable real-time communication.

The library features specialized modules for signal interpretation, event management, and optimized data transmission to servers or analytics systems. Its modular architecture allows for easy integration into existing applications, with flexible customization options to meet specific project requirements.

Built with Swift and taking full advantage of the latest iOS ecosystem improvements, tonetip_ios is the ideal tool for IoT projects and apps that demand precise, real-time monitoring and data analysis.
DESC
  s.homepage     = 'https://tonetip.com'
  s.license      = { :type => 'Copyright (c) 2025 ToneTip, all rights reserved.', :file => 'LICENSE.txt' }
  s.author       = { 'ToneTip' => 'dan@tonetip.com' }
  s.source       = { :git => 'https://github.com/Inowu/tonetip-swift.git', :tag => '1.0.1' }
  s.platform = :ios, '13.0'
  s.swift_versions = ['5.0']
  s.source_files = 'Tonetip-ios/**/*.{swift,h}'
end
