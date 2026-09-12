# Game and company discovery

Settings → About now places “Try our game” beside “About us”. The game card uses the current theme's subtle primary tint, a game-controller icon, and a short description of the route challenge. Both destinations have external-link icons and a localized browser-opening hint for accessibility. The existing expanded About section retains its Powered by Afdal credit.

- Company: https://www.afdal.tech/
- Game: https://game.laffa.afdal.tech/

Both links use the external browser, keeping Settings and the current trip in the app. A failed or throwing URL launch gives localized feedback instead of surfacing a platform exception. New copy is available in English, Arabic and French; the layout follows text direction and the active palette.

Validation: all 16 Settings tests passed, including external launch mode/destinations, retained Settings state, three languages at 180% text on a 360-pixel screen, and both false/throwing launch failures. Static analysis of the changed files and tests found no issues. The iOS simulator debug build passed, and the About section was visually checked on iPhone 17 / iOS 26.5. Tapping the game card opened the live game in Safari; returning to Laffah retained the Settings page and its scroll position.
