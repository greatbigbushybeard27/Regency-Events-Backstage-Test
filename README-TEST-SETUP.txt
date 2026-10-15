REGENCY EVENTS BACKSTAGE TEST
=============================

This package is based on the known-working V60 app. It is configured for a separate test Supabase project, not the live Regency project.

TEST SUPABASE
Project ID: narwmfzvidccocxowqqy
Project URL: https://narwmfzvidccocxowqqy.supabase.co
The publishable key is embedded in the test app files. It is intended for browser use; database security depends on the SQL policies.

IMPORTANT
- Do not upload these files over the live site.
- Do not run this SQL against the live Supabase project.
- This creates an empty test database. It does not copy live jobs, stock, users, vehicle bookings or crew records.
- Do not add a service-role/secret key to any app file.

DATABASE SETUP
1. Open https://supabase.com/dashboard and select project narwmfzvidccocxowqqy.
2. Open SQL Editor -> New query.
3. Open SUPABASE-TEST-SETUP.sql from this package, copy the entire contents, paste into the editor and run it.
4. Check the result panel for errors. If any statement fails, stop and send the exact error before continuing.
5. In Authentication -> Providers, ensure Email is enabled.
6. Create a test login in Authentication -> Users (or use the app's sign-up flow if enabled).
7. To give that account Director-only Casual Crew access, copy its Auth user UUID and run this query in the test project's SQL Editor, replacing the example UUID:

   insert into public.regency_casual_hs_directors(user_id)
   values ('00000000-0000-0000-0000-000000000000')
   on conflict do nothing;

8. Add a test material under Crew Management -> Casual Crew before testing the public induction page.

TEST WEBSITE SETUP
1. Create a NEW GitHub repository, for example Regency-Events-Backstage-Test. Do not use the live repository.
2. Extract this package and upload the CONTENTS of this folder to the new repository root, including index.html, manifest.webmanifest, sw.js, icon.svg, casual-induction.html and image assets. Do not upload the ZIP itself as the website.
3. Enable GitHub Pages for the new repository (Settings -> Pages -> deploy from main branch/root, if that option is available).
4. Open the test site URL and sign in with the test account only.
5. Install it as a separate PWA if desired. The service-worker cache name is different from the live app.

WHAT IS INCLUDED
- V60 app files configured for the new test project.
- Separate test org ID: regency-events-test.
- Test manifest name and a distinct service-worker cache name.
- SQL for shared state, H&S storage, Casual Crew induction, crew documents, and the V59.2 source metadata columns.
- The Casual Crew submission function includes a compatibility fix for ordering the returned table fields.

LIMITATIONS
- This is the safe test-site/database starter, not the requested feature-update release yet.
- The SQL creates schema and policies but does not seed test users or induction materials.
- The new Supabase project must be initialized by running the SQL yourself in its SQL Editor; I cannot execute SQL in your account from this chat.
- Verify the SQL completes successfully before publishing the test site. The publishable key is not a secret, but never share a database password or service-role/secret key.
