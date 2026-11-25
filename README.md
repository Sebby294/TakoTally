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
- Owner-only account management for assigning Staff and Production Head roles
- An ownership handoff requested by the current Owner and accepted by the recipient
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

#### Assign the first Owner role (admin-only)

New accounts start as Staff. To assign the initial Owner role, a trusted Supabase project administrator can run the following one-time command in PowerShell after creating the account.

The command prompts for the Project URL, the account UID from **Authentication → Users**, and the `service_role` key from **Project Settings → API Keys → Legacy API Keys**. These values are not included in this README. Treat the key as a password: never put it in website code, GitHub, or a shared note.

```powershell
$projectUrl = (Read-Host "Supabase Project URL").TrimEnd('/')
$userId = Read-Host "Account UID"
$secureKey = Read-Host "Service-role key" -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
$key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)

$headers = @{
    apikey = $key
    Authorization = "Bearer $key"
}
$uri = "$projectUrl/auth/v1/admin/users/$userId"

try {
    $user = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ErrorAction Stop
    $appMetadata = @{}

    if ($user.app_metadata) {
        $user.app_metadata.PSObject.Properties | ForEach-Object {
            $appMetadata[$_.Name] = $_.Value
        }
    }

    $appMetadata['role'] = 'Owner'
    $body = @{ app_metadata = $appMetadata } | ConvertTo-Json -Depth 10

    $updated = Invoke-RestMethod -Method Put -Uri $uri -Headers $headers `
        -ContentType 'application/json' -Body $body -ErrorAction Stop

    Write-Output "Updated $($updated.email) to role: $($updated.app_metadata.role)"
}
finally {
    $key = $null
    $headers = $null
    $secureKey = $null
}
```

Sign out and back in to TakoTally to refresh the session after the role is changed. This only assigns the app role; it does not configure database access or replace the need for appropriate RLS policies. Do not run this command in website code or as part of normal sign-up.

#### Set up account roles and ownership transfer

The Owner-only **Manage accounts** page and the **Ownership transfer** page use the `manage-user-roles` Edge Function. To enable ownership transfer, first apply the SQL migration, then deploy the function:

1. In Supabase, open **SQL Editor** and start a new query.
2. Open `supabase/migrations/20261126005300_owner_transfers.sql` from this project, copy its full contents into the SQL Editor, and run it. The migration creates a protected transfer table; browser users cannot read or change its rows.
3. From the project folder, install the Supabase CLI if needed, then authenticate and link this local project:

```text
supabase login
supabase link --project-ref <project-ref>
supabase functions deploy manage-user-roles
```

Find the project ref in the Supabase Project URL: it is the part before `.supabase.co`. Keep the function's JWT verification enabled. Supabase supplies the function's server-side environment variables, including its service-role key; never copy that key into this repository or browser code.

An Owner can select an existing Staff or Production Head account and send a transfer request. Ownership does not change until the recipient signs in and accepts. After acceptance, the recipient becomes Owner and the previous Owner becomes Production Head. The recipient should sign out and back in after completion to refresh their role. While a request is pending, the initiating Owner can cancel it and the recipient can decline it. If the function reports that a transfer is still processing, the recipient can use **Retry transfer**; this is designed to safely finish or confirm a partially completed handoff. A transfer record is retained for the involved accounts to see its latest status.

The function verifies the signed-in user's role on the server. Its ordinary role-management action can only assign Staff or Production Head; it cannot grant or remove Owner. Ownership changes are performed only by the recipient-acceptance flow. After an ordinary role change, the affected user must sign out and back in for the new role to appear in their session.

## Data and limitations

- Supabase Auth manages account credentials and sign-in. Inventory records and app settings are still saved in the browser's `localStorage`; they are specific to that browser profile and device, with no server-side or cross-device synchronization.
- Clearing the browser's site data can remove locally saved records and settings. Back up important information before clearing it.
- The current app disables inventory actions when the browser is offline.
- New accounts have the Staff role. Higher roles are read from trusted Supabase app metadata and cannot be selected in public sign-up.
- Inventory role-based interface restrictions are client-side, not server-enforced. The `manage-user-roles` Edge Function separately verifies Owner access for role changes. The current `items` table policy allows any authenticated user to read, add, edit, and delete its rows, and the app does not yet use that table. Keep using sample data; tighten database policies before connecting inventory or using real store data.
- Supabase's built-in email service has a low sending limit. Configure custom SMTP if the project needs to send more test or production emails.
- Google Fonts are loaded from Google Fonts when available; the page falls back to system fonts if they cannot be reached.

## Project structure

```text
TakoTally Project/
├── index.html
├── css/
│   └── styles.css
├── js/
│   ├── supabase-config.js
│   └── script.js
└── supabase/
    ├── config.toml
    ├── migrations/
    │   └── 20261126005300_owner_transfers.sql
    └── functions/
        └── manage-user-roles/
            └── index.ts
```