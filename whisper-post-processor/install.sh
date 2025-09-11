#!/bin/bash
# Install script for Whisper Post-Processor

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INSTALL_DIR="${HOME}/.local/bin"
JAR_NAME="whisper-post.jar"
SCRIPT_NAME="whisper-post"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "🚀 Installing Whisper Post-Processor..."
echo ""

# Check if Java is installed
if ! command -v java &> /dev/null; then
    echo -e "${RED}❌ Error: Java is not installed${NC}"
    echo "Please install Java 17 or later and try again"
    echo "  brew install openjdk"
    exit 1
fi

# Check Java version
JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
if [ "$JAVA_VERSION" -lt 17 ]; then
    echo -e "${YELLOW}⚠️  Warning: Java 17+ recommended (you have Java $JAVA_VERSION)${NC}"
fi

# Build if needed
if [ ! -f "$SCRIPT_DIR/dist/$JAR_NAME" ]; then
    echo "Building post-processor..."
    
    # Check if Gradle is installed
    if ! command -v gradle &> /dev/null; then
        echo -e "${RED}❌ Error: Gradle is not installed${NC}"
        echo "Please install Gradle:"
        echo "  brew install gradle"
        exit 1
    fi
    
    cd "$SCRIPT_DIR"
    gradle clean shadowJar --no-daemon > /dev/null 2>&1
    gradle buildAll --no-daemon > /dev/null 2>&1
    echo -e "${GREEN}✅ Built successfully${NC}"
fi

# Create install directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Copy JAR
echo "Installing JAR to $INSTALL_DIR..."
cp "$SCRIPT_DIR/dist/$JAR_NAME" "$INSTALL_DIR/$JAR_NAME"

# Create wrapper script
echo "Creating wrapper script..."
cat > "$INSTALL_DIR/$SCRIPT_NAME" << 'EOF'
#!/bin/bash
# Whisper Post-Processor wrapper
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
exec java -jar "$SCRIPT_DIR/whisper-post.jar" "$@"
EOF

chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

echo -e "${GREEN}✅ Installation complete!${NC}"
echo ""
echo "The post-processor has been installed to:"
echo "  JAR: $INSTALL_DIR/$JAR_NAME"
echo "  Script: $INSTALL_DIR/$SCRIPT_NAME"
echo ""

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo -e "${YELLOW}⚠️  Note: $INSTALL_DIR is not in your PATH${NC}"
    echo ""
    echo "Add this to your shell config (~/.zshrc or ~/.bashrc):"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

echo "📝 Configuration:"
echo ""
echo "The post-processor will be automatically detected by push_to_talk.lua"
echo ""
echo "If you need to specify a custom location, add to your ptt_config.lua:"
echo "  POST_PROCESSOR_JAR = \"$INSTALL_DIR/$JAR_NAME\""
echo ""
echo "Test the installation:"
echo "  echo 'theyconfigure the system' | $SCRIPT_NAME"
echo ""

# Test the installation
if [ -f "$INSTALL_DIR/$SCRIPT_NAME" ]; then
    echo -n "Testing... "
    TEST_OUTPUT=$(echo "test" | "$INSTALL_DIR/$SCRIPT_NAME" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Working!${NC}"
    else
        echo -e "${RED}❌ Test failed${NC}"
    fi
fi
