# Fork Sync Instructions

This document describes how to keep the Magnolia-Tech-Services-LLC/crawl4ai fork synchronized with the upstream unclecode/crawl4ai repository.

## Manual Sync Method

### Initial Setup (One-time)

```bash
# Navigate to your local fork
cd /path/to/crawl4ai

# Add upstream remote if not already added
git remote add upstream https://github.com/unclecode/crawl4ai.git

# Verify remotes
git remote -v
# Should show:
# origin    https://github.com/Magnolia-Tech-Services-LLC/crawl4ai.git (fetch)
# origin    https://github.com/Magnolia-Tech-Services-LLC/crawl4ai.git (push)
# upstream  https://github.com/unclecode/crawl4ai.git (fetch)
# upstream  https://github.com/unclecode/crawl4ai.git (push)
```

### Regular Sync Process

```bash
# 1. Fetch latest changes from upstream
git fetch upstream

# 2. Checkout main branch
git checkout main

# 3. Merge upstream changes
git merge upstream/main

# 4. Resolve any conflicts if they occur
# (Edit conflicted files, then:)
git add <resolved-files>
git commit -m "Merge upstream/main: resolve conflicts"

# 5. Push to your fork
git push origin main
```

## Automated Sync with GitHub Actions

Create `.github/workflows/sync-fork.yml` in your fork:

```yaml
name: Sync Fork with Upstream

on:
  schedule:
    # Run daily at 2 AM UTC
    - cron: '0 2 * * *'
  workflow_dispatch: # Allow manual trigger

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout fork
        uses: actions/checkout@v3
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Add upstream remote
        run: |
          git remote add upstream https://github.com/unclecode/crawl4ai.git || true
          git fetch upstream

      - name: Merge upstream
        run: |
          git checkout main
          git merge upstream/main || exit 0
          git push origin main
```

**Note**: This workflow will only work if there are no conflicts. For production use, consider a more sophisticated sync strategy.

## Best Practices

1. **Regular Sync**: Sync at least weekly to stay current with security updates
2. **Test After Sync**: After syncing, test your deployment to ensure nothing broke
3. **Review Changes**: Check what changed in upstream before merging
4. **Backup Custom Changes**: Keep track of any custom modifications you've made
5. **Conflict Resolution**: If conflicts occur, prioritize upstream changes unless your customizations are critical

## Custom Modifications

If you have custom modifications that conflict with upstream:

1. **Document Changes**: Keep a list of files you've modified
2. **Use Branches**: Create a branch for your customizations
3. **Cherry-pick**: Use `git cherry-pick` to apply specific upstream commits
4. **Rebase Strategy**: Consider rebasing your custom branch on upstream/main

## Files Modified for Coolify Deployment

Current customizations in this fork:
- `deploy/docker/config.yml` - Updated LLM provider to `ollama/qwen3:14b` and added Redis URI
- `deploy/docker/server.py` - Added REDIS_URI environment variable support

These changes should be preserved during sync. If upstream modifies these files, you'll need to manually merge the changes.

