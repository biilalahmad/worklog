import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

const site = process.env.PUBLIC_SITE_URL || 'https://worklog-site.netlify.app';

export default defineConfig({
  site,
  outDir: './dist',
  integrations: [sitemap({ filter: (page) => !page.includes('/invoice/') && !page.includes('/verified/') })],
  build: { format: 'directory' },
});
