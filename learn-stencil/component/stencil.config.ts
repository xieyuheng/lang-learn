import { Config } from "@stencil/core"
import { postcss } from "@stencil/postcss"
import tailwind from "proto-stencil-tailwind"
import tailwindcss from "tailwindcss"

export const config: Config = {
  namespace: "component",
  plugins: [
    // use postcss to importing tailwindcss preflight module
    postcss({
      plugins: [require("postcss-import")],
    }),
    tailwind({
      tailwind: tailwindcss("tailwind.config.js"),
      includeTailwindCss: false,
    }),
  ],
  devServer: { reloadStrategy: "pageReload" },
  outputTargets: [
    {
      type: "dist",
      esmLoaderPath: "../loader",
    },
    {
      type: "dist-custom-elements-bundle",
    },
    {
      type: "docs-readme",
    },
    {
      type: "www",
      serviceWorker: null, // disable service workers
    },
  ],
}
