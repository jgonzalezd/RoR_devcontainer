#!/bin/bash

echo "🔍 Verifying Rails + Vue.js Development Environment"
echo "================================================="

echo ""
echo "✅ Ruby: $(ruby --version)"
echo "✅ Rails: $(rails --version)"
echo "✅ Node.js: $(node --version)"
echo "✅ Vue CLI: $(vue --version)"

echo ""
echo "🗃️  PostgreSQL Configuration:"
echo "   Version: $POSTGRES_VERSION_INFO"
if pgrep -x postgres >/dev/null 2>&1; then
    echo "   Status: ✅ Running"
    if pg_isready -h localhost -p 5432 >/dev/null 2>&1; then
        echo "   Port 5432: ✅ Accepting connections"
    else
        echo "   Port 5432: ⚠️  Not ready"
    fi
else
    echo "   Status: ❌ Not running"
    echo "   Run: sudo service postgresql start"
fi

echo ""
echo "🔗 PostgreSQL Connection Test:"
DB_USER="${DATABASE_USERNAME:-dbuser}"
if pg_isready -h localhost -p 5432 >/dev/null 2>&1; then
    echo "✅ PostgreSQL: Ready for connections"
    echo "   Authentication: Trust-based (no password required)"
    echo "   User: $DB_USER"
    
    # Check if user database exists, create if not
    if PGPASSWORD="${DATABASE_PASSWORD:-password}" psql -h localhost -U "$DB_USER" -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "$DB_USER"; then
        echo "   Database: $DB_USER (available)"
    else
        echo "   Database: Creating $DB_USER database..."
        if PGPASSWORD="${DATABASE_PASSWORD:-password}" createdb -h localhost -U "$DB_USER" "$DB_USER" 2>/dev/null; then
            echo "   Database: $DB_USER (created)"
        else
            echo "   Database: $DB_USER (may need manual creation)"
        fi
    fi
else
    echo "⚠️  PostgreSQL: Not ready yet (container may still be starting)"
    echo "   PostgreSQL starts automatically with the container"
fi

echo ""
echo "🌐 Available Ports:"
echo "   - Rails API: http://localhost:3001"
echo "   - Vue.js App: http://localhost:3000 or 8080"
echo "   - Vite Dev: http://localhost:5173"
echo "   - PostgreSQL: localhost:5432"

echo ""
echo "🗃️  Database Connection String:"
echo "   postgresql://$DB_USER:${DATABASE_PASSWORD:-password}@localhost:5432/$DB_USER"

echo ""
echo "🛠️  Development Setup:"
echo "   - PostgreSQL Version: Parameterized (current: v$POSTGRES_VERSION)"
echo "   - Auth Method: Trust (passwordless for development)"
echo "   - Database User: $DB_USER (superuser)"
echo "   - Default Database: $DB_USER"

echo ""
echo "✅ Environment verification complete!" 