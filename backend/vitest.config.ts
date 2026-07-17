/**
 * Cấu hình Vitest cho unit test backend (mock repository, không cần DB thật).
 * Alias `@/*` -> `src/*` khớp tsconfig để test import giống code chính.
 */

import path from 'path';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
    },
  },
});
