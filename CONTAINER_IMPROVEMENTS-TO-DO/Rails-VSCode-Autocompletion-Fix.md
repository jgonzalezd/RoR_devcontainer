# Rails VSCode Autocompletion Issue & Solutions

## Problem Description

### The Issue
When editing Rails model files (e.g., `organization.rb`), VSCode provides **inaccurate autocompletion suggestions** for ActiveRecord associations. For example:

- **What happens:** Typing `has_many :` suggests non-existent models like `:organization_memberships`
- **What should happen:** Should suggest actual models like `:organizations_users` and `:organizations_projects` based on the project's actual model files

### Root Causes

1. **Missing or Deprecated Ruby Language Server**
   - No Ruby language server extension installed, OR
   - Using the deprecated "Ruby" extension by Peng Lv (no longer maintained as of 2024)
   - Without a language server, VSCode has no understanding of Ruby/Rails code structure

2. **Lack of Project Analysis**
   - VSCode cannot analyze Rails models, associations, or database schema without proper tooling
   - Cannot infer relationships between models and database tables
   - Cannot understand Rails conventions (pluralization, through associations, etc.)

3. **No Type Information**
   - Rails is dynamically typed - methods and associations are created at runtime
   - VSCode needs additional metadata (RBI files or YARD docs) to understand available methods
   - Without type information, autocompletion falls back to generic or cached suggestions

## Available Solutions

### Option 1: Ruby LSP + Tapioca (Recommended)

**Components:**
- **Ruby LSP Extension** (by Shopify) - Modern language server for Ruby
- **Tapioca Gem** - Generates RBI (Ruby Interface) type annotation files for Rails

**Pros:**
- ✅ Modern, actively maintained by Shopify (used in production at Shopify)
- ✅ Fast and lightweight
- ✅ Built-in Rails support with deep understanding of Rails conventions
- ✅ Tapioca automatically generates type annotations for:
  - Model associations (`has_many`, `belongs_to`, `has_one`)
  - Database schema (columns, types, validations)
  - ActiveRecord methods
  - Gem dependencies
- ✅ Works seamlessly with Sorbet (optional static type checker)
- ✅ Better performance on large codebases
- ✅ No separate language server process to manage

**Cons:**
- ⚠️ Requires adding gems to your project
- ⚠️ Relatively newer (less mature ecosystem than Solargraph)
- ⚠️ RBI files need to be regenerated after schema/model changes
- ⚠️ Adds `sorbet/` and `rbi/` directories to your project

**Implementation Steps:**

1. **Install Ruby LSP Extension in VSCode**
   ```
   - Open Extensions (Ctrl+Shift+X)
   - Search: "Ruby LSP"
   - Install: Ruby LSP by Shopify
   ```

2. **Add Gems to Gemfile**
   ```ruby
   group :development do
     gem "tapioca", require: false
     gem "sorbet-static-and-runtime"
   end
   ```

3. **Install and Initialize**
   ```bash
   cd /workspace/projects_own/construction-manager
   bundle install
   bundle exec tapioca init
   bundle exec tapioca dsl
   ```

4. **Configure Git** (add to `.gitignore` if desired)
   ```
   # Optional: ignore generated RBI files (or commit them for team consistency)
   /sorbet/rbi/dsl/**/*.rbi
   ```

5. **Workflow**
   - After schema changes: `bundle exec tapioca dsl`
   - After gem updates: `bundle exec tapioca gems`
   - Add to your development workflow or post-migration hook

### Option 2: Solargraph (Traditional)

**Components:**
- **Solargraph Extension** - Established Ruby language server
- **Solargraph Gem** - Provides the language server implementation

**Pros:**
- ✅ More mature and widely adopted
- ✅ Extensive documentation and community support
- ✅ Works with YARD documentation
- ✅ Good Rails plugin support
- ✅ Familiar to many Ruby developers

**Cons:**
- ⚠️ Slower on large codebases
- ⚠️ More configuration required
- ⚠️ Separate language server process runs in background
- ⚠️ Rails support requires additional configuration
- ⚠️ Less accurate with complex Rails associations
- ⚠️ Memory intensive on large projects

**Implementation Steps:**

1. **Install Solargraph Extension in VSCode**
   ```
   - Open Extensions (Ctrl+Shift+X)
   - Search: "Solargraph"
   - Install: Ruby Solargraph by castwide
   ```

2. **Add Gem to Gemfile**
   ```ruby
   group :development do
     gem "solargraph", require: false
     gem "solargraph-rails", require: false
   end
   ```

3. **Install and Configure**
   ```bash
   cd /workspace/projects_own/construction-manager
   bundle install
   bundle exec solargraph config
   ```

4. **Create/Update `.solargraph.yml`**
   ```yaml
   ---
   include:
     - "**/*.rb"
   exclude:
     - spec/**/*
     - test/**/*
     - vendor/**/*
     - tmp/**/*
   require:
     - solargraph-rails
   domains:
     - rails
   plugins:
     - solargraph-rails
   reporters:
     - rubocop
   max_files: 5000
   ```

5. **VSCode Settings** (optional, in `.vscode/settings.json`)
   ```json
   {
     "solargraph.diagnostics": true,
     "solargraph.formatting": true,
     "solargraph.hover": true
   }
   ```

## Comparison Matrix

| Feature | Ruby LSP + Tapioca | Solargraph |
|---------|-------------------|------------|
| Rails Association Accuracy | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐ Good |
| Performance | ⭐⭐⭐⭐⭐ Very Fast | ⭐⭐⭐ Moderate |
| Setup Complexity | ⭐⭐⭐ Medium | ⭐⭐⭐⭐ More Config |
| Maturity | ⭐⭐⭐ Newer | ⭐⭐⭐⭐⭐ Established |
| Memory Usage | ⭐⭐⭐⭐⭐ Low | ⭐⭐⭐ Higher |
| Rails Convention Understanding | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐ Good |
| Community Support | ⭐⭐⭐ Growing | ⭐⭐⭐⭐⭐ Large |
| Maintenance | ⭐⭐⭐⭐⭐ Active (Shopify) | ⭐⭐⭐⭐ Active |

## Recommendation

### For New Rails Projects (like construction-manager):
**Choose Ruby LSP + Tapioca** because:
- Best-in-class Rails understanding
- Fastest performance
- Modern architecture
- Backed by Shopify (long-term support guaranteed)
- Better integration with Rails 8

### For Existing Projects with Solargraph:
**Consider Migration if:**
- Experiencing slow autocompletion
- Need better Rails association support
- Want improved performance
- Team is open to new tooling

**Stay with Solargraph if:**
- Team is already familiar and productive
- Heavy reliance on YARD documentation
- Working well for your use case

## DevContainer Integration

### To automatically set up in devcontainer:

**Add to `.devcontainer/devcontainer.json`:**
```json
{
  "customizations": {
    "vscode": {
      "extensions": [
        "Shopify.ruby-lsp"
      ],
      "settings": {
        "rubyLsp.enableExperimentalFeatures": true,
        "rubyLsp.enabledFeatures": {
          "codeActions": true,
          "diagnostics": true,
          "documentHighlight": true,
          "documentLink": true,
          "documentSymbol": true,
          "foldingRange": true,
          "formatting": true,
          "hover": true,
          "inlayHint": true,
          "onTypeFormatting": true,
          "selectionRange": true,
          "semanticHighlighting": true
        }
      }
    }
  }
}
```

**Add to `postCreateCommand.sh` or `postStartCommand.sh`:**
```bash
# Generate Rails type annotations
if [ -f "Gemfile" ] && grep -q "tapioca" Gemfile; then
  echo "Generating Rails type annotations..."
  bundle exec tapioca dsl
fi
```

## Maintenance

### Ruby LSP + Tapioca Workflow:
```bash
# After migrations or model changes
bundle exec tapioca dsl

# After adding/updating gems
bundle exec tapioca gems

# Full regeneration
bundle exec tapioca dsl --verify
```

### Solargraph Workflow:
```bash
# Restart language server (from VSCode Command Palette)
> Solargraph: Restart

# Clear cache if needed
> Solargraph: Clear Cache
```

## What This Fixes

✅ **Accurate `has_many` / `belongs_to` suggestions** - Only suggests associations for models that actually exist  
✅ **Database column autocompletion** - Knows what columns exist on each model  
✅ **ActiveRecord method signatures** - Understands `.where`, `.find_by`, etc. with correct parameters  
✅ **Go-to-definition** - Jump to model/method definitions  
✅ **Inline documentation** - Hover over methods to see documentation  
✅ **Type checking** (with Sorbet) - Optional static type checking for Ruby  
✅ **Refactoring support** - Rename symbols across project  
✅ **Diagnostics** - Catches errors before running code  

## Next Steps

1. **Choose your solution** (Ruby LSP + Tapioca recommended)
2. **Test in one project first** (e.g., construction-manager)
3. **Verify autocompletion works** - Try editing `app/models/organization.rb`
4. **Document team workflow** - How to regenerate RBI files
5. **Add to devcontainer config** - Ensure new containers get the setup
6. **Roll out to other projects** - Once proven successful

## Resources

### Ruby LSP
- Documentation: https://shopify.github.io/ruby-lsp/
- GitHub: https://github.com/Shopify/ruby-lsp
- VSCode Extension: https://marketplace.visualstudio.com/items?itemName=Shopify.ruby-lsp

### Tapioca
- Documentation: https://github.com/Shopify/tapioca
- Rails Integration: https://github.com/Shopify/tapioca/wiki/Rails

### Solargraph
- Documentation: https://solargraph.org/
- GitHub: https://github.com/castwide/solargraph
- Rails Plugin: https://github.com/iftheshoefritz/solargraph-rails

### Sorbet
- Documentation: https://sorbet.org/
- VSCode Integration: https://sorbet.org/docs/vscode

---

**Status:** 📋 Documented - Ready for Implementation  
**Priority:** 🟡 Medium - Improves developer experience but not blocking  
**Effort:** 🔨 ~30 minutes per project (initial setup) + ~5 minutes per schema change  
**Impact:** 🚀 High - Significantly improves coding speed and accuracy

