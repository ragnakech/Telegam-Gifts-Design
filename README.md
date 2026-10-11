# Black Hole Gifts — Designers × AI

Concept for Telegram's iOS profile screen: when gifts are hidden, the floating gift bubbles are pulled into the Dynamic Island like a black hole, and fly back out when shown again.

## Try it
Open `index.html` in a browser (Chrome gives the best glass/lens effect). Go to Settings → Hide animation to switch between **Black hole**, **Fly**, and **Disintegrate** (snap glove + dust). Drag a gift to move it, swipe to spin the orbit; gifts push each other like soft bodies.

## Telegram-iOS patch
`telegram-ios-patch/` contains a patch against [Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS) (`PeerInfoGiftsCoverComponent.swift`, `PeerInfoHeaderNode.swift`): gifts spiral into the Dynamic Island, with three hide styles (`GiftHideStyle`, UserDefaults key `bhGiftHideStyle`).

**Status: not compiled** (no Mac/Xcode was available) — expect small build fixes. Not in the Swift patch: snap glove, sounds, swipe-to-spin, soft-body repulsion, settings UI wiring.

```sh
git clone https://github.com/TelegramMessenger/Telegram-iOS.git
cd Telegram-iOS && git apply ../telegram-ios-patch/black-hole-gifts.patch
```

## Notes
- The Dynamic Island can't be controlled by apps; the effect is drawn around it (island size is unchanged).
- Demo audio is not included for copyright reasons.
- Built with AI tools (Claude) under the author's direction.
