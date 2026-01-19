# 🌿 Vue 3 Code Review Generator

A powerful bash script that automates Vue 3 code review analysis by comparing two Git branches.

## Usage

Compare `feature/auth` branch against `origin/develop` base branch:

## Example

```bash
./vue-review.sh feature/auth --base origin/develop
```

## Output

The script generates a `.vue-review/` folder in your project root containing:
- **vue.diff** — Git diff between branches
- **project-context.md** — Vue project structure
- **review-prompt.md** — AI-ready review prompt
- **eslint-report.txt** — Linting results
- **features-matrix.md** — Changed files summary

## Next Steps

1. Review generated files in `.vue-review/`
2. Copy `review-prompt.md` content to your AI assistant
3. Add AI findings to `review-comments-deliverable.md`

## Tip

Add `.vue-review/` to your project's `.gitignore` to keep review files local:
```bash
echo ".vue-review/" >> .gitignore
```
