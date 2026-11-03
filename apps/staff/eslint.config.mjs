import nextVitals from 'eslint-config-next/core-web-vitals';
import nextTypeScript from 'eslint-config-next/typescript';
import prettier from 'eslint-config-prettier/flat';
import { defineConfig, globalIgnores } from 'eslint/config';

export default defineConfig([
  ...nextVitals,
  ...nextTypeScript,
  {
    rules: {
      // node_modules is flat (hoisted) for Expo, so an undeclared package can
      // still resolve. Fail instead: every import must be in package.json.
      'import/no-extraneous-dependencies': 'error',
    },
  },
  // Turn off rules that would fight Prettier's formatting. Must be last.
  prettier,
  globalIgnores(['.next/**', 'next-env.d.ts']),
]);
