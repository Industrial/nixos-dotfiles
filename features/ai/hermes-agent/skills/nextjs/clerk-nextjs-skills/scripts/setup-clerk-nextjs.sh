#!/bin/bash

# Clerk + Next.js 16 Setup Script
# This script automates the initial setup of Clerk authentication in a Next.js 16 project
# Usage: bash setup-clerk-nextjs.sh [--mcp]

set -e

INCLUDE_MCP=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mcp)
            INCLUDE_MCP=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: bash setup-clerk-nextjs.sh [--mcp]"
            exit 1
            ;;
    esac
done

echo "🔐 Clerk + Next.js 16 Setup Script"
echo ""

# Check if we're in a Next.js project
if [ ! -f "next.config.ts" ] && [ ! -f "next.config.js" ]; then
    echo "❌ Error: next.config.ts/js not found. Are you in a Next.js project root?"
    exit 1
fi

echo "✅ Next.js project detected"
echo ""

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ Error: Node.js 18+ required (you have Node.js $NODE_VERSION)"
    exit 1
fi

echo "✅ Node.js version: $(node -v)"
echo ""

# Check Next.js version
NEXT_VERSION=$(grep '"next":' package.json | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
if [ -z "$NEXT_VERSION" ]; then
    echo "⚠️  Could not determine Next.js version"
else
    NEXT_MAJOR=$(echo "$NEXT_VERSION" | cut -d'.' -f1)
    if [ "$NEXT_MAJOR" -lt 16 ]; then
        echo "⚠️  Warning: Next.js $NEXT_VERSION detected. Clerk proxy.ts requires Next.js 16+"
        echo "   Run: pnpm add next@latest"
    else
        echo "✅ Next.js version: $NEXT_VERSION"
    fi
fi

echo ""
echo "📦 Installing Clerk packages..."
pnpm add @clerk/nextjs

if [ "$INCLUDE_MCP" = true ]; then
    echo "📦 Installing MCP packages..."
    pnpm add @vercel/mcp-adapter @clerk/mcp-tools
fi

echo ""
echo "📝 Creating proxy.ts..."

# Determine location (root or src)
if [ -d "src" ]; then
    PROXY_PATH="src/proxy.ts"
else
    PROXY_PATH="proxy.ts"
fi

# Check if proxy.ts or middleware.ts already exists
if [ -f "$PROXY_PATH" ]; then
    echo "⚠️  $PROXY_PATH already exists. Skipping..."
elif [ -f "middleware.ts" ]; then
    echo "📋 Found middleware.ts - would you like to migrate to proxy.ts? (manual migration recommended)"
else
    cat > "$PROXY_PATH" << 'EOF'
import { clerkMiddleware } from '@clerk/nextjs/server'

export default clerkMiddleware()

export const config = {
  matcher: [
    // Skip Next.js internals and all static files, unless found in search params
    '/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)',
    // Always run for API routes
    '/(api|trpc)(.*)',
  ],
}
EOF
    echo "✅ Created $PROXY_PATH"
fi

echo ""
echo "📝 Creating .env.local..."

if [ -f ".env.local" ]; then
    echo "⚠️  .env.local already exists. Skipping..."
else
    cat > ".env.local" << 'EOF'
# Get these from https://dashboard.clerk.com/
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=your_publishable_key_here
CLERK_SECRET_KEY=your_secret_key_here

# Optional: Customize redirect URLs
NEXT_PUBLIC_CLERK_SIGN_IN_URL=/sign-in
NEXT_PUBLIC_CLERK_SIGN_UP_URL=/sign-up
NEXT_PUBLIC_CLERK_AFTER_SIGN_IN_URL=/
NEXT_PUBLIC_CLERK_AFTER_SIGN_UP_URL=/
EOF
    echo "✅ Created .env.local"
    echo ""
    echo "⚠️  Please update .env.local with your Clerk keys from https://dashboard.clerk.com/"
fi

echo ""
echo "📝 Updating app/layout.tsx..."

if grep -q "ClerkProvider" app/layout.tsx 2>/dev/null; then
    echo "✅ ClerkProvider already configured"
else
    cat > /tmp/layout-snippet.txt << 'EOF'
Import ClerkProvider at the top:
import { ClerkProvider } from '@clerk/nextjs'

Wrap your app with:
<ClerkProvider>
  <html>
    {/* ... */}
  </html>
</ClerkProvider>

See: https://clerk.com/docs/nextjs/getting-started/quickstart
EOF
    echo "⚠️  Please manually update app/layout.tsx:"
    cat /tmp/layout-snippet.txt
fi

if [ "$INCLUDE_MCP" = true ]; then
    echo ""
    echo "📝 MCP Server Setup Instructions"
    echo "==============================="
    echo "To set up an MCP server:"
    echo ""
    echo "1. Create app/[transport]/route.ts"
    echo "2. Create .well-known metadata endpoints"
    echo "3. Update proxy.ts to allow public access to .well-known"
    echo ""
    echo "See: references/CLERK_MCP_SERVER_SETUP.md"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Update .env.local with your Clerk keys"
echo "2. Update app/layout.tsx with ClerkProvider"
echo "3. Run: pnpm dev"
echo "4. Visit: http://localhost:3000"
echo ""
echo "Documentation:"
echo "- Quick Start: https://clerk.com/docs/nextjs/getting-started/quickstart"
echo "- Clerk API: https://clerk.com/docs/reference/nextjs/overview"
echo ""
