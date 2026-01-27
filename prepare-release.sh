#!/bin/bash
# Prepare iOS Extension for Initial Release

set -e  # Exit on error

echo "=================================================="
echo "  AEP Content Analytics iOS - Release Preparation"
echo "=================================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if version is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Version number required${NC}"
    echo "Usage: ./prepare-release.sh <version>"
    echo "Example: ./prepare-release.sh 1.0.0"
    exit 1
fi

VERSION=$1
echo -e "${GREEN}Preparing release version: $VERSION${NC}"
echo ""

# Step 1: Update version in Constants
echo "📝 Step 1: Updating version in ContentAnalyticsConstants.swift"
sed -i '' "s/EXTENSION_VERSION = \".*\"/EXTENSION_VERSION = \"$VERSION\"/" AEPContentAnalytics/Sources/Constants/Core/ContentAnalyticsConstants.swift
echo -e "${GREEN}✓ Version updated${NC}"
echo ""

# Step 2: Update podspec
echo "📝 Step 2: Updating version in AEPContentAnalytics.podspec"
sed -i '' "s/s.version.*= '.*'/s.version          = '$VERSION'/" AEPContentAnalytics.podspec
echo -e "${GREEN}✓ Podspec updated${NC}"
echo ""

# Step 3: Update CHANGELOG date
echo "📝 Step 3: Updating CHANGELOG.md with today's date"
TODAY=$(date +"%B %d, %Y")
sed -i '' "s/## $VERSION (TBD)/## $VERSION ($TODAY)/" CHANGELOG.md
echo -e "${GREEN}✓ CHANGELOG updated${NC}"
echo ""

# Step 4: Install dependencies
echo "📦 Step 4: Installing dependencies"
make pod-install
echo -e "${GREEN}✓ Dependencies installed${NC}"
echo ""

# Step 5: Run tests
echo "🧪 Step 5: Running tests"
make test
echo -e "${GREEN}✓ Tests passed${NC}"
echo ""

# Step 6: Run lint
echo "🔍 Step 6: Running SwiftLint"
make lint
echo -e "${GREEN}✓ Lint passed${NC}"
echo ""

# Step 7: Build archive
echo "🏗️  Step 7: Building XCFramework"
make archive
echo -e "${GREEN}✓ XCFramework built${NC}"
echo ""

echo "=================================================="
echo -e "${GREEN}✅ Release preparation complete!${NC}"
echo "=================================================="
echo ""
echo "Next steps:"
echo "1. Review changes: git status"
echo "2. Commit: git add . && git commit -m 'Prepare release $VERSION'"
echo "3. Tag: git tag -a v$VERSION -m 'Release version $VERSION'"
echo "4. Push: git push origin main && git push origin v$VERSION"
echo ""
echo "XCFramework available at: build/AEPContentAnalytics.xcframework"
echo ""

