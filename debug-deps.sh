#!/bin/bash
# Script para debuggear problemas de dependencias en Backstage

set -e

echo "🔍 Debugging Backstage Dependencies"
echo "=================================="

cd backstage

# Verificar arquitectura
echo "🏗️ Architecture Information:"
echo "Node version: $(node --version)"
echo "Platform: $(node -e 'console.log(process.platform)')"
echo "Arch: $(node -e 'console.log(process.arch)')"
echo ""

# Limpiar cache
echo "🧹 Cleaning caches..."
yarn cache clean
rm -rf node_modules/.cache
rm -rf .yarn/cache

# Verificar dependencias específicas problemáticas
echo "🔍 Checking problematic dependencies..."
echo ""

# Verificar si rollup está instalado
if yarn list @rollup/rollup-linux-arm64-gnu 2>/dev/null; then
    echo "❌ @rollup/rollup-linux-arm64-gnu found - this may cause issues"
else
    echo "✅ @rollup/rollup-linux-arm64-gnu not found - good"
fi

if yarn list @rollup/rollup-linux-x64-gnu 2>/dev/null; then
    echo "✅ @rollup/rollup-linux-x64-gnu found - this is expected for AMD64"
else
    echo "⚠️ @rollup/rollup-linux-x64-gnu not found"
fi

# Verificar Node.js native modules
echo ""
echo "🔍 Checking native modules..."
find node_modules -name "*.node" -type f 2>/dev/null | head -10 || echo "No .node files found yet"

# Test basic yarn commands
echo ""
echo "🧪 Testing yarn commands..."
yarn --version
yarn workspaces list --json | jq -r '.name' | head -5

echo ""
echo "🎯 Ready to attempt build with:"
echo "  NODE_ENV=production"
echo "  NODE_OPTIONS=--max-old-space-size=4096"
echo "  npm_config_optional=false"
echo ""
echo "Run: yarn build:backend"