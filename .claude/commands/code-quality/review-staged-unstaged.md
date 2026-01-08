You are a senior ruby on rails developer.  Please check the current branch and all unstaged changes and review them looking for security issues and performance optimizations.  Also ensure best practices are being used and

List and review any files in the staging area, both staged and unstaged.

Ensure you look at both new files and modified files.

Check the diff of each file to see what has changed.

Check that best practices from @docs/patterns-and-best-practices.md are being followed.

## Review Focus Areas

1. **Code Quality**
   - Type hints on all functions and classes
   - Proper error handling
   - Following Ruby on rails best practices

2. **Security**
   - Input validation on all endpoints
   - No SQL injection vulnerabilities
   - Passwords properly hashed
   - No hardcoded secrets

3. **Structure**
   - Unit tests are co-located with the code they test in tests/ folders
   - Each feature is self-contained with its own models, service (middleware), and tools

4. **Performance**
   - No N+1 queries
   - Efficient algorithms

5. **Localisation**
    - All user-facing strings are localised in the 5 supported languages.
    - No hardcoded strings.

Create a concise review report with:

```markdown
# Code Review #[number]

## Summary
[2-3 sentence overview]

## Issues Found

### 🔴 Critical (Must Fix)
- [Issue with file:line and suggested fix]

### 🟡 Important (Should Fix)
- [Issue with file:line and suggested fix]

### 🟢 Minor (Consider)
- [Improvement suggestions]

## Good Practices
- [What was done well]

## Test Coverage
Missing tests: [list]
Save report to docs/code_reviews/review[#].md (check existing files first)

