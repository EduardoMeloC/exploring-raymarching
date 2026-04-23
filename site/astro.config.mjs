// @ts-check
import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';

export default defineConfig({
  site: 'https://eduardomeloc.github.io/exploring-raymarching',
  base: '/exploring-raymarching/',
  output: 'static',
  integrations: [
    mdx(),
  ],
  markdown: {
    shikiConfig: {
      theme: 'one-dark-pro',
      langs: ['glsl', 'javascript', 'typescript', 'bash'],
    },
  },
});