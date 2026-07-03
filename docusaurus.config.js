// @ts-check
const { themes } = require('prism-react-renderer');

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Onze Work',
  tagline: 'Portal de Conhecimento Interno',
  favicon: 'img/favicon.ico',

  url: 'https://vctorAgto.github.io',
  baseUrl: '/knowledge-wiki-onze/',

  organizationName: 'vctorAgto',
  projectName: 'knowledge-wiki-onze',
  trailingSlash: false,

  onBrokenLinks: 'warn',
  onBrokenMarkdownLinks: 'warn',

  // sem i18n: pt-BR — evita o erro de webpack ProgressPlugin
  // o conteudo pode ser em portugues normalmente

  presets: [
    [
      'classic',
      {
        docs: {
          path: 'docs',
          routeBasePath: '/',
          sidebarPath: './sidebars.js',
        },
        blog: false,
        theme: { customCss: './src/css/custom.css' },
      },
    ],
  ],

  themeConfig: {
    navbar: {
      title: 'Onze Work',
      logo: { alt: 'Onze Work', src: 'img/logo.svg' },
      items: [
        {
          href: 'https://github.com/vctorAgto/knowledge-wiki-onze',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      copyright: `© ${new Date().getFullYear()} Onze Work`,
    },
    colorMode: { defaultMode: 'dark', disableSwitch: false },
    prism: { theme: themes.github, darkTheme: themes.dracula },
  },
};

module.exports = config;
