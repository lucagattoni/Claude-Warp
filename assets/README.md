# Brand assets

ClaudeWarp's logo, header banner, and social-preview image. The `.svg` files are the editable
vector masters; the `.png` files are exports for use where raster is required (GitHub renders both,
but PNG is the safe default for the README banner and the social preview).

| File | Format | Size | Use |
|---|---|---|---|
| [`claude-warp-header.png`](claude-warp-header.png) | PNG | 2560×800 | **README header banner** (referenced at the top of [`../README.md`](../README.md)) |
| [`claude-warp-header.svg`](claude-warp-header.svg) | SVG | vector | Editable master for the header banner |
| [`claude-warp-logo.png`](claude-warp-logo.png) | PNG | 1024×1024 | **Primary square logo** (full resolution) |
| [`claude-warp-logo-512.png`](claude-warp-logo-512.png) | PNG | 512×512 | Square logo, smaller raster (avatars, favicons) |
| [`claude-warp-logo.svg`](claude-warp-logo.svg) | SVG | vector | Editable master for the square logo |
| [`claude-warp-social-preview.jpg`](claude-warp-social-preview.jpg) | JPG | 2560×1280 | **GitHub social-preview image** — upload this one (≈220 KB, under GitHub's 1 MB limit) |
| [`claude-warp-social-preview.png`](claude-warp-social-preview.png) | PNG | 2560×1280 | Lossless social-preview export (≈2.6 MB — **too large for GitHub's upload**; use for other surfaces) |
| [`claude-warp-social-preview.svg`](claude-warp-social-preview.svg) | SVG | vector | Editable master for the social preview |

## Setting the GitHub social preview

The social-preview image (the card shown when the repo link is shared) is a **manual upload** — it
cannot be set via git or the CLI. Upload [`claude-warp-social-preview.jpg`](claude-warp-social-preview.jpg)
(the PNG is over GitHub's 1 MB upload limit):

**Settings → Options → Social preview → Edit → Upload an image**
(<https://github.com/lucagattoni/Claude-Warp/settings>)

## Editing

Edit the `.svg` master, then re-export the matching `.png` at the size in the table above. Keep the
palette consistent: deep indigo background, the orange pixel-creature, and the blue→white galaxy
spiral that gives "warp" its meaning.
