import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

const site = process.env.PUBLIC_SITE_URL || 'https://worklog.netlify.app';

export default defineConfig({
  site,
  outDir: './dist',
  integrations: [sitemap({ filter: (page) => !page.includes('/invoice/') })],
  build: { format: 'directory' },
});
