#!/bin/bash
set -e

echo "🚀 Launching OpenScreen with debug logging..."
echo ""
echo "To see the logs, run this in a separate terminal:"
echo "log stream --predicate 'process == \"OpenScreen\"' --level debug"
echo ""

# Kill any existing instances
killall OpenScreen 2>/dev/null || true

# Launch the app
open OpenScreen.app

echo "✅ OpenScreen launched!"
echo ""
echo "📋 What to expect:"
echo "1. A window titled 'Select Video Source' should appear"
echo "2. The Screen tab should be selected by default"
echo "3. If you see a permission alert:"
echo "   - Click 'Open System Settings'"
echo "   - Grant screen recording permission"
echo "   - Click 'Retry' in the alert"
echo "4. You should see your display(s) listed"
echo ""
echo "🔍 To see debug logs, run:"
echo "log stream --predicate 'process == \"OpenScreen\"' --level debug"
