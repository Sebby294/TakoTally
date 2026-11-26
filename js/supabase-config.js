// Replace these placeholders with your project's URL and publishable key.
window.takoEmailVerificationRedirect =
    new URLSearchParams(window.location.search).get('verified') === '1';

const SUPABASE_URL = 'https://zkgobragnhhuwegqdfwg.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_EqIV-lhVnjCNwu4n5lHqXw_pXY2Xs1s';

if (!SUPABASE_URL || !SUPABASE_PUBLISHABLE_KEY) {
    console.error('Supabase is not configured. Add the Project URL and publishable key in js/supabase-config.js.');
} else if (!window.supabase || !window.supabase.createClient) {
    console.error('Supabase JS did not load. Check your internet connection and the Supabase CDN script in index.html.');
} else {
    window.takoSupabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);
}
