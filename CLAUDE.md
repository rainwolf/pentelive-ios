# penteLive iOS

## Device Compatibility

All UI changes must work on both **iPhone and iPad**. Before finalizing any layout or UI code, verify it renders correctly on both form factors. Watch for:

- Hardcoded sizes or margins that break on larger screens
- iPhone-only navigation patterns (e.g. push-only flows that should use split view on iPad)
- Popover vs modal presentation (use `UIPopoverPresentationController` on iPad where appropriate)
- Rotation and size class handling (`UIUserInterfaceSizeClass` compact vs regular)
