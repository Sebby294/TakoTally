# TakoTally

TakoTally is a browser-based inventory tracker for the Legendary Takoyaki production office. It helps staff record supplies received by the office and supplies released to branches, while keeping an eye on stock levels.

> **Project status:** This is a work in progress. The current version is a client-side prototype, not a production-ready, multi-user service.

## Features

- Dashboard with current balances, low-stock indicators, search, and category filters
- Stock-in and stock-out records, including dates, suppliers, branches, and non-delivery reasons
- Inventory reports with weekly, monthly, and custom date ranges; reports can be printed or saved as PDF through the browser
- Branch comparisons for quantities released
- Item management, configurable low-stock thresholds, and transaction editing, deletion, and restoration
- Staff, Production Head, and Owner roles
- Light and dark themes

## Getting started

There is no build step or package installation. Serve this folder with a local web server—for example, use the VS Code Live Server extension, or run Python's built-in server from this directory:

```text
python -m http.server 8000
```

Then open [http://localhost:8000](http://localhost:8000) in a modern browser. A secure browser context (such as `localhost` or HTTPS) is needed for account login.

The app loads from `index.html`; its styles and behavior are in `css/styles.css` and `js/script.js`.

## Data and limitations

- Accounts and inventory records are saved in the browser's `localStorage`. They are specific to that browser profile and device; there is no server or cross-device synchronization.
- Clearing the browser's site data can remove saved accounts and records. Back up important information before clearing it.
- The current app disables inventory actions when the browser is offline.
- The app uses client-side account and role handling. Do not use it to protect sensitive information or as a substitute for a server-backed authentication system.
- Google Fonts are loaded from Google Fonts when available; the page falls back to system fonts if they cannot be reached.

## Project structure

```text
TakoTally Project/
├── index.html
├── css/
│   └── styles.css
└── js/
    └── script.js
```