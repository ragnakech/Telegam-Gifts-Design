# Black Hole Gifts — Designers × AI

Concept for Telegram's iOS profile screen: when gifts are hidden, the floating gift bubbles are pulled into the Dynamic Island like a black hole, and fly back out when shown again.

## Try it
Open `index.html` in a browser (Chrome gives the best glass/lens effect). Go to Settings → Hide animation to switch between **Black hole**, **Fly**, and **Disintegrate** (snap glove + dust). Drag a gift to move it, swipe to spin the orbit; gifts push each other like soft bodies.

## Telegram-iOS patch
`telegram-ios-patch/` contains a patch against [Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS) (`PeerInfoGiftsCoverComponent.swift`, `PeerInfoHeaderNode.swift`):
- gifts spiral into the Dynamic Island with a glowing ring around it (island size unchanged);
- three hide styles (`GiftHideStyle`: black hole / straight / disintegrate; UserDefaults key `bhGiftHideStyle`, set via `GiftHideStyle.current = ...`);
- soft-body spacing: gifts are pushed apart so they never overlap;
- disintegrate style: silver snap glove (shape layers, pinch animation), dust particles, a procedurally generated snap sound and haptic.

**Status: not compiled** (no Mac/Xcode was available) — expect small build fixes. Web demo only (not in the Swift patch): swipe-to-spin orbit, music with ducking, glass lens refraction, touch cursor, Settings UI. In Telegram the gifts do not orbit, and the Settings screen is not wired to the style picker.

```sh
git clone https://github.com/TelegramMessenger/Telegram-iOS.git
cd Telegram-iOS && git apply ../telegram-ios-patch/black-hole-gifts.patch
```

## Notes
- The Dynamic Island can't be controlled by apps; the effect is drawn around it (island size is unchanged).
- Demo audio is not included for copyright reasons.
- Built with AI tools (Claude) under the author's direction.
