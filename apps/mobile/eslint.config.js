const { defineConfig, globalIgnores } = require('eslint/config');
const expoConfig = require('eslint-config-expo/flat');
const prettier = require('eslint-config-prettier/flat');

module.exports = defineConfig([
  expoConfig,
  {
    rules: {
      // node_modules is flat (hoisted) for Expo, so an undeclared package can
      // still resolve. Fail instead: every import must be in package.json.
      'import/no-extraneous-dependencies': 'error',
    },
  },
  // Turn off rules that would fight Prettier's formatting. Must be last.
  prettier,
  globalIgnores(['dist/**', '.expo/**', 'expo-env.d.ts']),
]);
