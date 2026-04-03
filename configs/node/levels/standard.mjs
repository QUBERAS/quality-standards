// Level: standard
// Recommended rules + common footguns. Recommended for active repos.

import js from "@eslint/js";

export default [
  js.configs.recommended,
  {
    rules: {
      // ── Core errors ──────────────────────────────────────────────────
      "no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
      "no-undef": "error",

      // ── Likely bugs ──────────────────────────────────────────────────
      "no-constant-condition": "error",
      "no-dupe-args": "error",
      "no-dupe-keys": "error",
      "no-duplicate-case": "error",
      "no-empty": ["error", { allowEmptyCatch: true }],
      "no-extra-boolean-cast": "error",
      "no-func-assign": "error",
      "no-inner-declarations": "error",
      "no-irregular-whitespace": "error",
      "no-unreachable": "error",
      "no-unsafe-finally": "error",
      "no-unsafe-negation": "error",
      "use-isnan": "error",
      "valid-typeof": "error",

      // ── Best practices ───────────────────────────────────────────────
      eqeqeq: ["error", "always", { null: "ignore" }],
      "no-eval": "error",
      "no-implied-eval": "error",
      "no-extend-native": "error",
      "no-new-wrappers": "error",
      "no-throw-literal": "error",
      "no-self-compare": "error",
      "no-sequences": "error",
      "no-template-curly-in-string": "warn",
      "no-unmodified-loop-condition": "warn",
      "prefer-const": "error",
      "no-var": "error",
      "prefer-template": "warn",

      // ── Security ─────────────────────────────────────────────────────
      "no-new-func": "error",
    },
  },
];
