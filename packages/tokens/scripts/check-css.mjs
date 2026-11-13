// Fails if tokens.css drifts from the colour values in src/index.ts.
import { readFile } from 'node:fs/promises';

const ts = await readFile(new URL('../src/index.ts', import.meta.url), 'utf8');
const css = await readFile(new URL('../tokens.css', import.meta.url), 'utf8');

const palette = Object.fromEntries(
  [...ts.matchAll(/^\s+(\w+): '(#[0-9A-Fa-f]{6})',$/gm)].map(([, k, v]) => [k, v.toLowerCase()]),
);

const scheme = (name) => {
  const block = ts.match(new RegExp(`export const ${name}: ColorScheme = \\{([\\s\\S]*?)\\};`))[1];
  return Object.fromEntries(
    [...block.matchAll(/(\w+): palette\.(\w+)/g)].map(([, role, key]) => [role, palette[key]]),
  );
};

const kebab = (s) => s.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`);
// Returns the body of the first rule whose selector matches, or null.
const cssBlock = (selectorPattern) => {
  const match = css.match(new RegExp(`(?:^|\\n)${selectorPattern}\\s*\\{([^}]*)\\}`));
  return match ? match[1] : null;
};

let failures = 0;
for (const [name, selectorPattern, label] of [
  ['light', ':root', ':root'],
  // Either quote style, so formatters can't silently break the check.
  ['dark', `:root\\[data-theme=["']dark["']\\]`, ':root[data-theme="dark"]'],
]) {
  const block = cssBlock(selectorPattern);
  if (block === null) {
    console.error(`tokens.css has no ${label} rule for the ${name} theme`);
    failures++;
    continue;
  }
  for (const [role, value] of Object.entries(scheme(name))) {
    const match = block.match(new RegExp(`--chom-${kebab(role)}: (#[0-9a-f]{6});`));
    if (!match || match[1] !== value) {
      console.error(
        `${name}.${role}: expected ${value}, tokens.css has ${match?.[1] ?? 'nothing'}`,
      );
      failures++;
    }
  }
}

// Subject fills: subjectColors.light / .dark against --chom-subject-* in each theme.
for (const [name, selectorPattern] of [
  ['light', ':root'],
  ['dark', `:root\\[data-theme=["']dark["']\\]`],
]) {
  const block = cssBlock(selectorPattern) ?? '';
  const ts_block = ts.match(new RegExp(`\\n  ${name}: \\{([\\s\\S]*?)\\n  \\}`))?.[1] ?? '';
  const entries = [...ts_block.matchAll(/(\w+): '(#[0-9A-Fa-f]{6})'/g)];
  if (!entries.length) {
    console.error(`subjectColors.${name} not found in src/index.ts`);
    failures++;
  }
  for (const [, family, value] of entries) {
    const match = block.match(new RegExp(`--chom-subject-${kebab(family)}: (#[0-9a-f]{6});`));
    if (match?.[1] !== value.toLowerCase()) {
      console.error(
        `subjectColors.${name}.${family}: expected ${value.toLowerCase()}, tokens.css has ${match?.[1] ?? 'nothing'}`,
      );
      failures++;
    }
  }
}

if (failures) process.exit(1);
console.log('tokens.css matches src/index.ts');
