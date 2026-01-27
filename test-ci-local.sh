#!/bin/bash
set -e

echo "=== Matching CI Environment Locally ==="
echo ""
echo "CI Setup:"
echo "- Runner: macos-15"
echo "- Ruby: 3.3.0 (from .ruby-version)"
echo "- CocoaPods: 1.16.2 (from Gemfile)"
echo "- Xcode: 16.4"
echo "- iOS: Latest available for iPhone 16"
echo ""

# Check current setup
echo "Your Local Setup:"
echo "- Ruby: $(ruby --version | cut -d' ' -f1-2)"
echo "- CocoaPods: $(bundle exec pod --version 2>/dev/null || echo 'Not installed via bundle')"
echo "- Xcode: $(xcodebuild -version | head -1)"
echo ""

# Set encoding (CI requirement)
export LANG=en_US.UTF-8

# Clean build
echo "1. Cleaning..."
make clean

# Install dependencies (exact CI command)
echo "2. Installing dependencies..."
bundle exec pod install --repo-update

# Run tests (exact CI command - no version specified)
echo "3. Running tests..."
make unit-test-ios IOS_DEVICE_NAME="iPhone 16"

echo ""
echo "✅ Tests completed successfully!"
