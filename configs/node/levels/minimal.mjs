// Level: minimal
// Core ESLint errors only. Starting point for legacy repos.

import js from "@eslint/js";

export default [
  js.configs.recommended,
  {
    rules: {
      // Only real errors — unused vars, undeclared refs, etc.
      "no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
      "no-undef": "error",
    },
  },
];
