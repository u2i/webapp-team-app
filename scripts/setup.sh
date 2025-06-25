#!/bin/bash
set -euo pipefail

echo "🚀 Setting up U2I Infrastructure with Terramate"

# Check if running on macOS or Linux
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="darwin"
    echo "📦 Installing Terramate on macOS..."
    if command -v brew &> /dev/null; then
        brew install terramate
    else
        echo "❌ Homebrew not found. Please install Terramate manually from:"
        echo "   https://github.com/terramate-io/terramate/releases"
        exit 1
    fi
else
    OS="linux"
    echo "📦 Installing Terramate on Linux..."
    curl -Lo terramate https://github.com/terramate-io/terramate/releases/latest/download/terramate_linux_amd64
    chmod +x terramate
    sudo mv terramate /usr/local/bin/
fi

# Verify installation
echo "✅ Terramate version:"
terramate version

# Initialize Terramate
echo "🔧 Initializing Terramate..."
terramate init

# Generate files
echo "📝 Generating Terramate files..."
terramate generate

# List all stacks
echo "📋 Available stacks:"
terramate list

echo "✨ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Deploy bootstrap:     cd foundation/0-bootstrap && terraform init && terraform apply"
echo "2. Deploy organization:  cd foundation/1-organization && terramate run terraform init && terramate run terraform apply"
echo "3. Deploy security:      cd foundation/2-security && terramate run terraform init && terramate run terraform apply"
echo "4. Deploy apps:          cd apps/webapp/prod && terramate run terraform init && terramate run terraform apply"