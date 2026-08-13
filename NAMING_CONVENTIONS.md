# 📛 Argus Naming Conventions

## Overview
This document explains the naming scheme across the Argus project.

---

## ✅ Current Naming (No Changes Needed)

### User-Facing Names (Already "Argus")
- **CLI Command**: `argus` ✅
- **Project Display Name**: "Argus" or "Argus Agent" ✅
- **Documentation**: Refers to "Argus" ✅

### Internal Python Package (Keep as `sre_agent`)
- **Folder**: `sre_agent/` 
- **Imports**: `from sre_agent import ...`
- **Why keep?**: Renaming would break 100+ import statements across files

**Analogy**: Think of it like Django's internal package is `django/` but users call it "Django".

---

## 🔧 AWS Resources (Configurable Names)

You can name AWS resources anything you want. Current defaults:

### Runtime Names
**Current**: `argus_sre_agent` or `argus_sre_agent_v2`
**Suggestion**: Use `argus_runtime` or `argus_prod`

**To change:**
```bash
# When deploying
bash deployment/build_and_deploy.sh argus_runtime
```

### Memory Names  
**Current**: `sre_agent_memory` (hardcoded in `sre_agent/memory/config.py`)
**Suggestion**: `argus_memory`

**To change:**
```python
# In sre_agent/memory/config.py
class MemoryConfig(BaseModel):
    memory_name: str = Field(
        default="argus_memory",  # Changed from sre_agent_memory
        description="Name of the AgentCore memory resource"
    )
```

### Gateway Names
**Current**: `myagentcoregatewayargus-sre-agent-gateway-afxx7va5es` (AWS auto-generated)
**Can't change**: AWS assigns the ID automatically

### Credential Provider  
**Current**: `sre-agent-api-key-credential-provider`
**Suggestion**: `argus-api-key-credential-provider`

**To change**: Update `CREDENTIAL_PROVIDER_NAME` in scripts:
```bash
# In all scripts that reference it
export CREDENTIAL_PROVIDER_NAME="argus-api-key-credential-provider"
```

---

## 🎯 Recommended Approach

**Option 1: Keep Everything As-Is (Easiest)**
- Internal package: `sre_agent/`
- CLI command: `argus` ✅
- User docs: Say "Argus" ✅
- AWS resources: Use `argus_*` names going forward

**Option 2: Rename AWS Resources Only (Medium)**
- Update memory name: `argus_memory`
- Update credential provider: `argus-api-key-credential-provider`
- Use `argus_runtime` for new deployments
- Keep Python package as `sre_agent/`

**Option 3: Full Rename (Most Work - Not Recommended)**
- Rename folder: `sre_agent/` → `argus/`
- Update all imports across 50+ files
- High risk of breaking things
- Minimal benefit (internal name doesn't matter)

---

## 📝 If You Choose Option 2 (Rename AWS Resources)

### Step 1: Update Memory Name

```bash
# Edit sre_agent/memory/config.py
sed -i 's/default="sre_agent_memory"/default="argus_memory"/g' sre_agent/memory/config.py

# Commit
git add sre_agent/memory/config.py
git commit -m "chore: rename memory resource to argus_memory"
```

### Step 2: Update Credential Provider Name

```bash
# Edit backend/servers/retrieve_api_key.py
sed -i 's/DEFAULT_CREDENTIAL_PROVIDER_NAME = "sre-agent-api-key-credential-provider"/DEFAULT_CREDENTIAL_PROVIDER_NAME = "argus-api-key-credential-provider"/g' backend/servers/retrieve_api_key.py

# Update all scripts
sed -i 's/sre-agent-api-key-credential-provider/argus-api-key-credential-provider/g' scripts/*.sh

# Update STARTUP_CHECKLIST.md
sed -i 's/sre-agent-api-key-credential-provider/argus-api-key-credential-provider/g' STARTUP_CHECKLIST.md
```

### Step 3: Create New AWS Resources

**On EC2:**
```bash
cd ~/argus

# 1. Create new credential provider with new name
cd gateway
python create_credentials_provider.py \
  --name argus-api-key-credential-provider \
  --region ap-south-1

# 2. The next deployment will use new runtime name
export CREDENTIAL_PROVIDER_NAME="argus-api-key-credential-provider"
bash deployment/build_and_deploy.sh argus_runtime

# 3. Memory will auto-create with new name on first agent run
uv run argus --provider anthropic --prompt "test"
# Creates: argus_memory (instead of sre_agent_memory)
```

### Step 4: Clean Up Old Resources

**In AWS Console:**
1. Navigate to Bedrock → AgentCore (ap-south-1 region)
2. Delete old resources:
   - Old runtime: `argus_sre_agent`
   - Old memory: `sre_agent_memory` (if it exists)
   - Old credential provider: `sre-agent-api-key-credential-provider`

---

## 🚫 Don't Change These

**Never rename:**
- Python package folder: `sre_agent/` (too risky)
- Git repository: `argus-sre-agent` (would break clone URLs)
- EC2 folder: `~/argus` (just a convenience, not critical)

**Why?** These are deeply embedded and changing them provides no user benefit.

---

## ✅ Summary

**What users see:**
- CLI: `argus` ✅
- Docs: "Argus" ✅

**What developers see:**
- Code: `import sre_agent` (internal, doesn't matter)

**What AWS sees:**
- Resources: `argus_*` (configurable, rename if you want)

**Bottom line:** The system already presents itself as "Argus" to users. The `sre_agent` folder is just internal plumbing. Renaming AWS resources is optional and cosmetic.

---

## 💡 My Recommendation

**Keep Option 1** - don't rename anything. The project is already called "Argus" everywhere it matters. The internal Python package name is irrelevant to users.

If you really want consistency, use **Option 2** and rename AWS resources going forward, but leave the Python package alone.
