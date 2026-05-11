import { defineConfig } from 'deepsec/config'

export default defineConfig({
  projects: [
    { id: 'dotfiles', root: '..' },
    // <deepsec:projects-insert-above>
  ],
})
