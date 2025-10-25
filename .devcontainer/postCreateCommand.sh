#!/bin/bash -l

echo "🎉 DevContainer created successfully!"
echo ""
echo "Verifying build-time tools..."
echo "✅ Ruby: $(ruby --version 2>/dev/null || echo '❌ Not found')"
echo "✅ Rails: $(rails --version 2>/dev/null || echo '❌ Not found')"
echo "✅ Node.js: $(node --version 2>/dev/null || echo '❌ Not found')"
echo "✅ npm: $(npm --version 2>/dev/null || echo '❌ Not found')"
echo "✅ yarn: $(yarn --version 2>/dev/null || echo '❌ Not found')"
echo "✅ Vue CLI: $(vue --version 2>/dev/null || echo '❌ Not found')"
echo ""
echo "📝 Note: Full environment verification (including PostgreSQL) will run after container starts."

echo "alias ra=./bin/dev" >> ~/.bashrc
echo "alias rs='./bin/rails server'" >> ~/.bashrc 
