#!/bin/bash
set -e
PROJECT_NAME=TestProject

# Run from repo root so path to podspec is correct.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Clean up.
rm -rf $PROJECT_NAME
mkdir -p $PROJECT_NAME && cd $PROJECT_NAME
swift package init
# Use Xcodegen to generate the project (iOS). YAML requires indentation for nested keys.
cat > project.yml << YAML_EOF
name: $PROJECT_NAME
options:
  bundleIdPrefix: $PROJECT_NAME
targets:
  $PROJECT_NAME:
    type: framework
    sources: Sources
    platform: iOS
    deploymentTarget: "15.0"
    settings:
      GENERATE_INFOPLIST_FILE: YES
YAML_EOF
xcodegen generate
# Create a Podfile with our pod as dependency.
echo "
platform :ios, '15.0'
target '$PROJECT_NAME' do
use_frameworks!
pod 'AEPCore', '~> 5.0'
pod 'AEPServices', '~> 5.0'
pod 'AEPEdge', '~> 5.0'
pod 'AEPContentAnalytics', :path => '../AEPContentAnalytics.podspec'
end
" >>Podfile
pod install

# Archive for generic iOS device
echo '############# Archive for generic iOS device ###############'
xcodebuild archive -scheme TestProject -workspace TestProject.xcworkspace -destination 'generic/platform=iOS'

# Build for generic iOS device
echo '############# Build for generic iOS device ###############'
xcodebuild clean build -scheme TestProject -workspace TestProject.xcworkspace -destination 'generic/platform=iOS'

# Archive and build for iOS simulator
echo '############# Archive for iOS simulator ###############'
xcodebuild archive -scheme TestProject -workspace TestProject.xcworkspace -destination 'generic/platform=iOS Simulator'

echo '############# Build for iOS simulator ###############'
xcodebuild clean build -scheme TestProject -workspace TestProject.xcworkspace -destination 'generic/platform=iOS Simulator'

# Clean up.
cd ..
rm -rf $PROJECT_NAME
# tvOS
mkdir -p $PROJECT_NAME && cd $PROJECT_NAME
swift package init
cat > project.yml << YAML_EOF
name: $PROJECT_NAME
options:
  bundleIdPrefix: $PROJECT_NAME
targets:
  $PROJECT_NAME:
    type: framework
    sources: Sources
    platform: tvOS
    deploymentTarget: "15.0"
    settings:
      GENERATE_INFOPLIST_FILE: YES
YAML_EOF
xcodegen generate
echo "
platform :tvos, '15.0'
target '$PROJECT_NAME' do
use_frameworks!
pod 'AEPCore', '~> 5.0'
pod 'AEPServices', '~> 5.0'
pod 'AEPEdge', '~> 5.0'
pod 'AEPContentAnalytics', :path => '../AEPContentAnalytics.podspec'
end
" >>Podfile
pod install

echo '############# Archive for generic tvOS device ###############'
xcodebuild archive -scheme TestProject -workspace TestProject.xcworkspace -destination 'generic/platform=tvOS'

echo '############# Build for generic tvOS device ###############'
xcodebuild build -scheme TestProject -workspace TestProject.xcworkspace -destination 'generic/platform=tvOS'

echo '############# Archive for tvOS simulator ###############'
xcodebuild archive -scheme TestProject -workspace TestProject.xcworkspace -destination 'generic/platform=tvOS Simulator'

echo '############# Build for tvOS simulator ###############'
xcodebuild build -scheme TestProject -workspace TestProject.xcworkspace -destination 'generic/platform=tvOS Simulator'

# Clean up.
cd ..
rm -rf $PROJECT_NAME
