# Node.js quickstart

Get your Node.js repo compliant with QUBERAS quality standards. Works the same whether it's a Next.js full-stack app, a standalone React frontend, or a plain Express backend — each repo calls the same reusable workflow.

## 1. Run every check locally (before touching CI)

### Quick setup

```bash
npm install --save-dev eslint prettier typescript
```

Your project should already have an `eslint.config.mjs` (ESLint flat config). If not, create one — see [framework-specific configs](#framework-specific-eslint-configs) below.

### Run each check

```bash
# ── Lint (are there code issues?) ──────────────────────────────────────────
npx eslint .

# ── Format (is the code formatted correctly?) ─────────────────────────────
# Uses quality-standards prettier config
curl -fsSL https://raw.githubusercontent.com/QUBERAS/quality-standards/main/configs/node/.prettierrc.json -o /tmp/qs-prettier.json
npx prettier --check --config /tmp/qs-prettier.json "src/**/*.{ts,tsx,js,jsx,mjs,css,json}"

# ── Type check (does TypeScript compile?) ──────────────────────────────────
npx tsc --noEmit

# ── Dependency audit (known vulnerabilities in your deps?) ─────────────────
npm audit --audit-level=high

# ── Secrets (any leaked keys/tokens?) ──────────────────────────────────────
# Install: brew install trufflehog (mac) or see https://github.com/trufflesecurity/trufflehog
trufflehog git file://. --since-commit HEAD --only-verified --fail

# ── CVE scan (vulnerabilities in your container/files?) ────────────────────
# Install: brew install trivy (mac) or see https://github.com/aquasecurity/trivy
trivy fs --scanners vuln --severity CRITICAL,HIGH .
```

### Auto-fix what you can

```bash
npx eslint --fix .
npx prettier --write --config /tmp/qs-prettier.json "src/**/*.{ts,tsx,js,jsx,mjs,css,json}"
```

## 2. Add CI

Create `.github/workflows/quality.yml`:

```yaml
name: Quality
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: ["**"]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  quality:
    uses: QUBERAS/quality-standards/.github/workflows/node.yml@main
    with:
      node-version: "20"
      audit: true                   # npm audit (default: true)
      typecheck: true               # tsc --noEmit (default: true)
      commitlint: true              # conventional commits on PR titles (default: true)
    secrets: inherit
```

### What runs in CI

| Check | Tool | Blocks merge | How to control |
|-------|------|-------------|----------------|
| Lint | ESLint (project config) | yes | project's eslint.config.mjs |
| Format | Prettier (quality-standards config) | yes | always on |
| Type check | tsc --noEmit | yes | `typecheck: true/false` |
| Dependency audit | npm audit | yes | `audit: true/false` |
| Secrets | TruffleHog | yes | always on |
| CVE scan | Trivy | yes | `trivy-severity` input (default: CRITICAL,HIGH) |
| PR title | commitlint | yes (PR only) | `commitlint: true/false` |

## 3. Framework-specific ESLint configs

The quality-standards workflows run `npx eslint .` — they use whatever ESLint config your project ships. Here's what to use for common setups:

### Next.js (full-stack or frontend)

`create-next-app` generates this automatically:

```js
// eslint.config.mjs
import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  globalIgnores([".next/**", "out/**", "build/**", "next-env.d.ts"]),
]);

export default eslintConfig;
```

```bash
npm install --save-dev eslint eslint-config-next
```

### React (standalone frontend, e.g. Vite)

```js
// eslint.config.mjs
import js from "@eslint/js";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";
import tseslint from "typescript-eslint";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    plugins: {
      "react-hooks": reactHooks,
      "react-refresh": reactRefresh,
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      "react-refresh/only-export-components": ["warn", { allowConstantExport: true }],
    },
  },
  { ignores: ["dist/**"] },
);
```

```bash
npm install --save-dev eslint @eslint/js typescript-eslint eslint-plugin-react-hooks eslint-plugin-react-refresh
```

### Plain Node.js backend (Express, Fastify, etc.)

```js
// eslint.config.mjs
import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  { ignores: ["dist/**", "node_modules/**"] },
);
```

```bash
npm install --save-dev eslint @eslint/js typescript-eslint
```

### JavaScript only (no TypeScript)

```js
// eslint.config.mjs
import js from "@eslint/js";

export default [
  js.configs.recommended,
  { ignores: ["dist/**", "node_modules/**"] },
];
```

```bash
npm install --save-dev eslint @eslint/js
```

## 4. Split repos (separate frontend + backend)

If your project is split across two repos (e.g. `myapp-frontend` and `myapp-backend`), each repo gets its own `quality.yml` calling `node.yml` independently. No special configuration needed — each repo has its own:

- `eslint.config.mjs` — framework-appropriate rules (Next.js for frontend, plain TS for backend)
- `tsconfig.json` — project-specific TypeScript config
- `package.json` + `package-lock.json` — own dependency tree

The CI checks are identical. The only difference is which ESLint plugins each repo installs.

```
myapp-frontend/
  .github/workflows/quality.yml  ──► calls node.yml (same)
  eslint.config.mjs              ──► eslint-config-next
  tsconfig.json

myapp-backend/
  .github/workflows/quality.yml  ──► calls node.yml (same)
  eslint.config.mjs              ──► @eslint/js + typescript-eslint
  tsconfig.json
```

## Prettier config

CI fetches the prettier config from quality-standards automatically. For local IDE support, you can copy it into your repo:

```bash
curl -fsSL https://raw.githubusercontent.com/QUBERAS/quality-standards/main/configs/node/.prettierrc.json -o .prettierrc.json
```

The config enforces: double quotes, semicolons, 120 char line width, trailing commas, LF line endings.

## Skipping checks during dev

```bash
SKIP=eslint git commit -m "wip: debugging"   # skip specific pre-commit hooks (if installed)
git commit --no-verify                         # skip all hooks
```

CI enforces on PR — clean up before opening one.
