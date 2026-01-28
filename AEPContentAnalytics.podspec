Pod::Spec.new do |s|
  s.name             = "AEPContentAnalytics"
  s.version          = "5.0.0-beta.1"
  s.summary          = "Content Analytics extension for Adobe Experience Platform Mobile SDK."
  
  s.description      = <<-DESC
  The AEPContentAnalytics extension enables content and experience tracking for mobile applications integrated with Adobe Experience Platform.
  Features include:
  - Asset tracking (images, media)
  - Experience tracking (complex UI components)
  - Automatic batching and aggregation
  - Privacy-compliant data collection
  - Edge Network integration
  - ML model featurization support
  DESC

  s.homepage         = "https://github.com/adobe/aca-mobile-sdk-ios-extension"
  s.license          = { :type => "Apache License, Version 2.0", :file => "LICENSE" }
  s.author           = "Adobe Experience Platform SDK Team"
  s.source           = { :git => "https://github.com/adobe/aca-mobile-sdk-ios-extension.git", :tag => s.version.to_s }

  s.ios.deployment_target = "15.0"
  s.tvos.deployment_target = "15.0"

  s.swift_version = "5.1"

  s.pod_target_xcconfig = { 'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES' }

  s.source_files = "AEPContentAnalytics/Sources/**/*.swift"

  s.dependency "AEPCore", ">= 5.0.0", "< 6.0.0"
  s.dependency "AEPServices", ">= 5.0.0", "< 6.0.0"
  s.dependency "AEPEdge", ">= 5.0.0", "< 6.0.0"
end

