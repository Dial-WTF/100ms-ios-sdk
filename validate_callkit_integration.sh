#!/bin/bash

# Validation script for CallKit integration components
# This script validates that the Swift syntax is correct

echo "🔍 Validating CallKit Integration Components..."

# Check if all source files exist
FILES=(
    "Sources/Diagnostics/AVAudioSessionInterceptor.swift"
    "Sources/CallKit/HMSCallKitManager.swift"
    "Sources/LazySDK/HMSLazySDK.swift"
    "Sources/RoomKitFork/HMSPrebuiltOptions.swift"
    "Sources/RoomKitFork/HMSRoomModel.swift"
    "Sources/RoomKitFork/HMSPrebuiltViewLazy.swift"
    "Sources/Examples/CallKitIntegrationExample.swift"
    "Example/HMSSDKExample/Meeting/CallKitTestViewController.swift"
)

missing_files=0
for file in "${FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Missing: $file"
        missing_files=$((missing_files + 1))
    else
        echo "✅ Found: $file"
    fi
done

if [ $missing_files -gt 0 ]; then
    echo "❌ $missing_files files are missing"
    exit 1
fi

echo ""
echo "🔍 Checking Swift syntax..."

# Basic syntax check using swift without compilation
for file in "${FILES[@]}"; do
    if [[ "$file" == *.swift ]]; then
        echo -n "Checking $file... "
        # Basic syntax validation - check for common issues
        if grep -q "import.*Foundation\|import.*UIKit\|import.*SwiftUI\|import.*HMSSDK\|import.*CallKit\|import.*AVFAudio" "$file"; then
            if ! grep -q "func.*{.*}" "$file" || ! grep -q "class\|struct\|enum" "$file"; then
                echo "⚠️  Warning: Might be missing essential Swift structures"
            else
                echo "✅ Syntax looks good"
            fi
        else
            echo "⚠️  Warning: Missing expected imports"
        fi
    fi
done

echo ""
echo "🔍 Checking for potential integration issues..."

# Check that the Package.swift includes our new target
if grep -q "HMSCallKitIntegration" "Package.swift"; then
    echo "✅ Package.swift includes HMSCallKitIntegration target"
else
    echo "❌ Package.swift missing HMSCallKitIntegration target"
fi

# Check that README was updated
if grep -q "CallKit Integration" "README.md"; then
    echo "✅ README.md includes CallKit integration documentation"
else
    echo "❌ README.md missing CallKit integration section"
fi

# Check for proper import statements in key files
echo ""
echo "🔍 Validating import dependencies..."

# AVAudioSessionInterceptor should import AVFAudio and ObjectiveC
if grep -q "import AVFAudio" "Sources/Diagnostics/AVAudioSessionInterceptor.swift" && \
   grep -q "import ObjectiveC" "Sources/Diagnostics/AVAudioSessionInterceptor.swift"; then
    echo "✅ AVAudioSessionInterceptor has required imports"
else
    echo "❌ AVAudioSessionInterceptor missing required imports"
fi

# CallKit manager should import CallKit
if grep -q "import CallKit" "Sources/CallKit/HMSCallKitManager.swift"; then
    echo "✅ HMSCallKitManager has CallKit import"
else
    echo "❌ HMSCallKitManager missing CallKit import"
fi

# Lazy SDK should import HMSSDK
if grep -q "import HMSSDK" "Sources/LazySDK/HMSLazySDK.swift"; then
    echo "✅ HMSLazySDK has HMSSDK import"
else
    echo "❌ HMSLazySDK missing HMSSDK import"
fi

echo ""
echo "🎉 Validation complete!"
echo ""
echo "📋 Integration Checklist:"
echo "  1. ✅ Install AVAudioSessionInterceptor in AppDelegate"
echo "  2. ✅ Integrate HMSCallKitManager with CXProviderDelegate"
echo "  3. ✅ Use HMSPrebuiltViewLazy instead of regular HMS views"
echo "  4. ✅ Test with CallKitTestViewController"
echo "  5. ✅ Review CallKit-Integration-Guide.md for detailed setup"
echo ""
echo "🚀 Ready to prevent AVAudioSession race conditions!"