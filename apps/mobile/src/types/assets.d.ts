// Types for importing assets with ES `import` syntax, e.g.
//   import logo from '@/assets/images/icon.png';
// Expo SDK 58 types `require('./x.png')` out of the box but not `import`, so
// the declarations live here and are committed (CI and fresh checkouts need them).
// Metro resolves images to an image source and fonts to an asset id.

/// <reference types="expo/types" />

declare module '*.png' {
  import type { ImageSourcePropType } from 'react-native';
  const value: ImageSourcePropType;
  export default value;
}

declare module '*.jpg' {
  import type { ImageSourcePropType } from 'react-native';
  const value: ImageSourcePropType;
  export default value;
}

declare module '*.jpeg' {
  import type { ImageSourcePropType } from 'react-native';
  const value: ImageSourcePropType;
  export default value;
}

declare module '*.gif' {
  import type { ImageSourcePropType } from 'react-native';
  const value: ImageSourcePropType;
  export default value;
}

declare module '*.webp' {
  import type { ImageSourcePropType } from 'react-native';
  const value: ImageSourcePropType;
  export default value;
}

declare module '*.ttf' {
  const value: number;
  export default value;
}

declare module '*.otf' {
  const value: number;
  export default value;
}
