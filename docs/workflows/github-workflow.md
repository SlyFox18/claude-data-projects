# GitHub Workflow Guide

## Daily Workflow

### Starting Your Work Day
1. Open GitHub Desktop
2. Click "Fetch origin" to get latest changes
3. Open VS Code and your project

### Making Changes
1. Make your changes in Power BI/Fabric
2. Export/save files to your project folder
3. Update documentation (README, context.md)

### Committing Changes
1. Open GitHub Desktop
2. Review changed files (left panel)
3. Write descriptive commit message
4. Click "Commit to main"
5. Click "Push origin"

## Creating a New Project

1. Copy template: `/templates/project-structure/`
2. Create new folder: `/projects/[project-name]/`
3. Fill out README.md and context.md
4. Add your files
5. Commit and push

## Best Practices

### Commit Often
- After each meaningful change
- Before switching tasks
- End of each work session

### Write Good Commit Messages
Good: `feat: Add YTD filters to Physical Inventory report`  
Bad: `update`

### What to Commit
COMMIT:
- Documentation
- DAX measures (.txt or .dax files)
- M code (.pq or .m files)
- Screenshots
- Small sample data

DON'T COMMIT:
- Large data files (>10MB)
- Temporary files
- Cache files
- Personal credentials

## Troubleshooting

### "Failed to push"
- Make sure you've committed first
- Check your internet connection
- Try "Fetch origin" first

### "Merge conflict"
- Open the file in VS Code
- Look for conflict markers
- Choose which version to keep
- Save and commit
