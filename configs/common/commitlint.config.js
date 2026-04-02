// Conventional Commits config for all QUBERAS repos.
// Copy to repo root as commitlint.config.js
//
// Format: <type>(<scope>): <subject>
// Examples:
//   feat(trading): add stop-loss order type
//   fix(auth): handle expired JWT correctly
//   chore(deps): bump ruff to 0.8.0

module.exports = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "type-enum": [
      2,
      "always",
      [
        "feat",
        "fix",
        "chore",
        "docs",
        "refactor",
        "test",
        "ci",
        "perf",
        "revert",
        "style",
        "build",
      ],
    ],
    "header-max-length": [2, "always", 100],
    "subject-full-stop": [2, "never", "."],
    "subject-case": [2, "always", "lower-case"],
    "scope-case": [1, "always", "lower-case"],
  },
};
