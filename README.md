# TakoTally

TakoTally is a browser-based inventory tracker for the Legendary Takoyaki production office. It helps staff record supplies received by the office and supplies released to branches, while keeping an eye on stock levels.

> **Project status:** This is a work in progress for prototype and team testing. Inventory data is shared through Supabase, but review access policies, backups, and operational needs before using this for production.

## Features

- Dashboard with current balances, low-stock indicators, search, and category filters
- Stock-in and stock-out records, including dates, suppliers, branches, and non-delivery reasons
- Inventory reports with weekly, monthly, and custom date ranges; reports can be printed or saved as PDF through the browser
- Branch comparisons for quantities released
- Item management, configurable low-stock thresholds, and transaction editing, deletion, and restoration
- Supabase email/password sign-up and login; new accounts start as Staff
- Account settings for display name, email, password changes, and forgotten-password recovery
- Staff, Production Head, and Owner role-aware interface
- Owner-only account management for role assignments and reversible Staff/Production Head deactivation
- An ownership handoff requested by the current Owner and accepted by the recipient
- Light and dark themes

## Getting started

There is no build step or package installation. Serve this folder with a local web server—for example, use the VS Code Live Server extension, or run Python's built-in server from this directory:

```text
python -m http.server 8000
```

Then open [http://localhost:8000](http://localhost:8000) in a modern browser. A secure browser context (such as `localhost` or HTTPS) is needed for account login.

The app loads from `index.html`; its styles and behavior are in `css/styles.css` and `js/script.js`.

### Deploying to Vercel

Import the GitHub repository containing TakoTally into Vercel. If `index.html` is inside a subfolder in the repository, set that folder as the **Root Directory**. This is a static site with no build step: choose **Other** as the framework preset, leave **Build Command** blank, and use `.` as the **Output Directory**.

After deployment, pushes to the connected Git branch will trigger new deployments. In Supabase **Authentication → URL Configuration**, set the Site URL to the production Vercel URL and add that URL followed by `/**` to Redirect URLs. Keep your local development URL there too if you still use it. Database migrations and Supabase Edge Functions are configured separately; deploying the frontend to Vercel does not deploy them.

### Supabase setup

1. In `js/supabase-config.js`, enter your Supabase Project URL and publishable key. Never put a secret or `service_role` key in browser code.
2. Enable the Email provider in Supabase Authentication.
3. In **Authentication → URL Configuration**, set the Site URL to the address you use to run the app, and add that address to Redirect URLs. For the Python server above, use `http://localhost:8000/` as the Site URL and `http://localhost:8000/**` as a Redirect URL. For Live Server, use its actual host and port instead.
4. Open TakoTally through that web server, not by opening `index.html` directly as a `file://` URL. Create an account from the app. If email confirmation is enabled, the confirmation link returns to the app with a verification marker; after Supabase confirms the email, TakoTally shows a success page with a **Return to login** button. Keep the app's origin (including your Vercel domain when deployed) in Supabase's allowed Redirect URLs; password reset and email-change confirmations return to that origin.

#### Set up shared inventory

Before using inventory, run the full contents of `supabase/migrations/20261126234500_shared_inventory.sql` once in the Supabase **SQL Editor**. This creates a separate set of `inventory_*` tables; it does not change the existing sample `public.items` table.

This is a clean start: the migration seeds the app's catalogue, default low-stock thresholds, and four branches, but does not import prototype quantities, transactions, custom items, or local settings. Shared stock therefore starts at zero. Existing prototype data in this browser's `localStorage` is left untouched as a backup and is not uploaded or synchronized. After the migration is applied, sign in again or refresh TakoTally to load the shared inventory. Each teammate must use the same Supabase project configuration and have an account in that project.

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

After updating the project files, redeploy `manage-user-roles` with the command above so the Owner's account list also displays each user's edited display name.

An Owner can assign roles to, deactivate, or reactivate existing Staff and Production Head accounts. Deactivation is reversible and blocks future sign-ins; it does not delete the Auth account. Existing sessions may remain usable until their access tokens expire. Owners cannot change their own access or deactivate Owner accounts. Accounts involved as the recipient in a pending or processing ownership transfer cannot be deactivated until that transfer is resolved. Permanent account deletion is not available in TakoTally and is reserved for a trusted Supabase project administrator.

An Owner can select an existing active Staff or Production Head account and send a transfer request. Ownership does not change until the recipient signs in and accepts. After acceptance, the recipient becomes Owner and the previous Owner becomes Production Head. The recipient should sign out and back in after completion to refresh their role. While a request is pending, the initiating Owner can cancel it and the recipient can decline it. If the function reports that a transfer is still processing, the recipient can use **Retry transfer**; this is designed to safely finish or confirm a partially completed handoff. A transfer record is retained for the involved accounts to see its latest status.

The function verifies the signed-in user's role on the server. Its role-management action can only assign Staff or Production Head; it cannot grant or remove Owner. Ownership changes are performed only by the recipient-acceptance flow. After an ordinary role change, the affected user must sign out and back in for the new role to appear in their session.

## Data and limitations

- Supabase Auth manages account credentials and sign-in. Shared catalogue, thresholds, branches, conversions, stock entries, and branch movements are stored in the project's `inventory_*` tables.
- Signed-in users can update their display name and change their email or password from **Account settings**. Email changes may require confirmation from Supabase. Users who forget their password can request a reset link from the login screen.
- The original prototype snapshot in browser `localStorage` is retained as a backup but is not used as the live inventory or synced to Supabase. Clearing site data can remove local preferences and that prototype backup; it does not delete shared database records.
- TakoTally requires a connection to Supabase to load and change shared inventory; inventory actions are disabled while offline.
- New accounts have the Staff role. Higher roles are read from trusted Supabase app metadata and cannot be selected in public sign-up.
- Inventory tables enforce role and record validation with Supabase row-level security and database triggers. The `manage-user-roles` Edge Function separately verifies Owner access for account-role changes. The existing sample `items` table is not used by the app; its current policy allows any authenticated user to read, add, edit, and delete sample rows.
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
    │   ├── 20261126005300_owner_transfers.sql
    │   └── 20261126234500_shared_inventory.sql
    └── functions/
        └── manage-user-roles/
            └── index.ts
```