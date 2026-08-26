import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';

export default defineConfig({
    plugins: [
        laravel({
            input: [
                'resources/js/app.js',
                'resources/js/client.js',
                'resources/sass/app.scss',
            ],
            refresh: true,
        }),
    ],

    build: {
        manifest: 'manifest.json',
        outDir: 'public/build',
        emptyOutDir: true,
    },
});
