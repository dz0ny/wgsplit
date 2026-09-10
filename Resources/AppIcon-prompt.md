# App icon

Created with the built-in image generation tool. `AppIcon.png` is the source image.
`AppIcon.iconset` contains the macOS sizes. `AppIcon.icns` is used by the app bundle.

## Xcode

`Assets.xcassets` contains the `AppIcon` asset set with all ten macOS icon sizes.
`WGSplit.xcodeproj` includes this catalog and selects `AppIcon` for the app target.

The command-line build uses Swift Package Manager and a bundle script. The
bundle script continues to use `AppIcon.icns`.

## Prompt

Use case: logo-brand. Create one finished macOS application icon for WGSplit, a menu-bar app that splits network traffic between a WireGuard tunnel and a direct connection. A bold shield with a clear branching route inside it: one path splits into two. Simple distinctive geometry, thick clean shapes readable at small sizes, refined native macOS app-icon finish with restrained depth. Centered rounded-square tile with generous outer transparent padding. No text, no letters, no watermark, no mockup, no extra symbols. Square 1024x1024 output. Background outside the rounded-square tile must be transparent.
