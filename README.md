# TakoTally

TakoTally is a browser-based inventory tracker for the Legendary Takoyaki production office. It helps staff record supplies received by the office and supplies released to branches, while keeping an eye on stock levels.

> **Project status:** This is a work in progress. The current version is a client-side prototype, not a production-ready, multi-user service.

## Features

- Dashboard with current balances, low-stock indicators, search, and category filters
- Stock-in and stock-out records, including dates, suppliers, branches, and non-delivery reasons
- Inventory reports with weekly, monthly, and custom date ranges; reports can be printed or saved as PDF through the browser
- Branch comparisons for quantities released
- Item management, configurable low-stock thresholds, and transaction editing, deletion, and restoration
- Supabase email/password sign-up and login; new accounts start as Staff
- Staff, Production Head, and Owner role-aware interface
- Light and dark themes

## Getting started

There is no build step or package installation. Serve this folder with a local web server—for example, use the VS Code Live Server extension, or run Python's built-in server from this directory:

```text
python -m http.server 8000
```

Then open [http://localhost:8000](http://localhost:8000) in a modern browser. A secure browser context (such as `localhost` or HTTPS) is needed for account login.

The app loads from `index.html`; its styles and behavior are in `css/styles.css` and `js/script.js`.

### Supabase setup

1. In `js/supabase-config.js`, enter your Supabase Project URL and publishable key. Never put a secret or `service_role` key in browser code.
2. Enable the Email provider in Supabase Authentication.
3. In **Authentication → URL Configuration**, set the Site URL to the address you use to run the app, and add that address to Redirect URLs. For the Python server above, use `http://localhost:8000/` as the Site URL and `http://localhost:8000/**` as a Redirect URL. For Live Server, use its actual host and port instead.
4. Create an account from TakoTally. If email confirmation is enabled, confirm it from the email before logging in.

## Data and limitations

- Supabase Auth manages account credentials and sign-in. Inventory records and app settings are still saved in the browser's `localStorage`; they are specific to that browser profile and device, with no server-side or cross-device synchronization.
- Clearing the browser's site data can remove locally saved records and settings. Back up important information before clearing it.
- The current app disables inventory actions when the browser is offline.
- New accounts have the Staff role. Higher roles are read from trusted Supabase app metadata and cannot be selected in public sign-up.
- Role-based interface restrictions are client-side, not server-enforced. The current `items` table policy allows any authenticated user to read, add, edit, and delete its rows, and the app does not yet use that table. Keep using sample data; tighten database policies before connecting inventory or using real store data.
- Supabase's built-in email service has a low sending limit. Configure custom SMTP if the project needs to send more test or production emails.
- Google Fonts are loaded from Google Fonts when available; the page falls back to system fonts if they cannot be reached.

## Project structure

```text
TakoTally Project/
├── index.html
├── css/
│   └── styles.css
└── js/
    ├── supabase-config.js
    └── script.js
```