# Viola Ordelia — A Little Space of Creativity

Starter portfolio website using HTML/CSS/JavaScript + Supabase + GitHub Pages. Content and images are stored in Supabase, so ordinary content updates do not require a new GitHub deployment.

## What's included

- Responsive public portfolio, pastel theme, opening intro, theme toggle, language switcher, scroll reveal, gallery lightbox, anonymous feedback form.
- Separate `admin.html` dashboard with password-only login, overview, JSON content editor, photo upload, private feedback management, password change, preview and logout.
- Supabase SQL migration, Edge Function, storage bucket setup, and local password-hash generator.

## Important setup notes

1. The supplied initial password `212009` is intentionally **not** embedded in the code. It is too short and easy to guess. Before publishing, generate a strong unique password (at least 12 characters) using `tools/generate-password.html` opened locally, then run its generated SQL in Supabase. Keep the password private.
2. This is a beginner-friendly first release. Admin content editing is implemented as section JSON editing (plus a guided photo upload form), not a full Canva-like drag-and-drop editor. `Manage Languages` stores translation JSON, while the public language switcher currently translates the main navigation and core headings. Add further translations in `js/main.js` to translate every content string.
3. Uploaded images are limited to 8 MB and JPG/PNG/WebP. Video links can be added to works JSON as content metadata, but the public gallery currently renders image items only.
4. The login rate limiter uses Supabase database records and blocks an IP hash after repeated failures. Edge Functions can run in multiple isolates; the SQL rate-limit table provides shared state.
5. Do not add private phone numbers, home addresses, or sensitive personal details to the public portfolio.

## 1. Create Supabase project

1. Open https://supabase.com and create a project.
2. Open **SQL Editor** → **New query**.
3. Paste and run `supabase/migrations/001_initial.sql`.
4. Open **Project Settings → API**. Copy the Project URL and `anon` public key. Do not copy or expose the `service_role` key into frontend files.
5. Open **Edge Functions → Secrets** (or use the Supabase CLI) and set:
   - `SUPABASE_URL` = project URL
   - `SERVICE_ROLE_KEY` = secret API key (server-side only; the Edge Function reads this exact name)
   - `ADMIN_SESSION_SECRET` = long random secret, at least 32 random bytes
   - `RATE_LIMIT_PEPPER` = another random secret
   Supabase automatically provides the project URL and service role key to Edge Functions in standard deployments; verify these are present. Add the two custom secrets.
6. Open `tools/generate-password.html` locally (double-click the file). Enter a unique password with at least 12 characters and press Generate hash. Copy the generated SQL and run it in Supabase SQL Editor. The password itself is never sent to Supabase by this helper; only its PBKDF2 hash and salt are inserted.

## 2. Deploy the Edge Function

Install Supabase CLI by following the official guide: https://supabase.com/docs/guides/cli. In a terminal, from this project folder, run:

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy admin-api
```

The Edge Function uses a custom short-lived HMAC session for password-only access. It verifies the session on every admin action. Public feedback is accepted only through a constrained insert action; feedback cannot be listed by the public client.

## 3. Configure the frontend

Edit `js/config.js`:

```js
window.PORTFOLIO_CONFIG = {
  SUPABASE_URL: 'https://YOUR-PROJECT.supabase.co',
  SUPABASE_ANON_KEY: 'YOUR_SUPABASE_ANON_KEY',
  EDGE_FUNCTION_URL: 'https://YOUR-PROJECT.supabase.co/functions/v1/admin-api',
  STORAGE_BUCKET: 'portfolio-media'
};
```

The publishable key is designed for frontend use. Never paste `SERVICE_ROLE_KEY` or any secret here.

## 4. Publish on GitHub Pages

1. Create a new GitHub repository, for example `viola-portfolio`.
2. Upload all files and folders from this project (keep folder structure).
3. In GitHub, open **Settings → Pages**.
4. Under Build and deployment, choose **Deploy from a branch**, branch `main`, folder `/ (root)`, then Save.
5. Wait for the Pages URL to appear. Open it and test the public site.
6. If your repo is not named `<username>.github.io`, GitHub Pages serves it under `https://<username>.github.io/<repository>/`. The relative CSS/JS paths in this project support that setup.

## 5. Admin usage

1. Scroll to the footer and select **Admin Access**.
2. Enter the password you generated. There is no email or username field.
3. Use **Upload Photos** to add an image. The image is uploaded to the public `portfolio-media` bucket and a works item is saved in the database.
4. Use **Manage My Works** to edit/delete/reorder gallery items in the JSON array. Keep each item shaped like:

```json
{
  "id": "unique-id",
  "title": "A little moment",
  "description": "Short description",
  "category": "Photography",
  "year": "2026",
  "image_url": "https://...",
  "storage_path": "works/..."
}
```

5. Use the section editors to edit About, Hobbies, Experiences, Skills, Contact, Languages, and Settings. Keep valid JSON syntax. Click Save Changes.
6. **Private Feedback** shows anonymous visitor notes. Mark them read or delete them. No public read policy exists for this table.
7. **Website Settings** includes the password change form. Use a unique password of at least 12 characters.
8. Use **Preview Website** or **Back to Website** to return to the public site. Logout ends the browser session.

## 6. Add your profile photo

The profile image can be changed by uploading it through Upload Photos, then copying its resulting public image URL into the `profile` section's `image_url` field using **Edit About Me**. The starter placeholder is `assets/images/profile-placeholder.svg`.

## 7. Security checklist before sharing

- Confirm `service_role` key is absent from every frontend file and GitHub commit.
- Confirm `212009` is not used as the published password; use a strong password.
- Confirm `admin_credentials` and `private_feedback` have RLS enabled and no anon/authenticated policies.
- Confirm only `portfolio_content` has a public SELECT policy.
- Test wrong passwords and repeated failures; after six failures the IP hash is temporarily blocked.
- Test feedback from a private/incognito browser; verify public users cannot query `private_feedback`.
- Do not store personal phone numbers, home address, school schedules, or other sensitive details in public content.

## Troubleshooting

- **Backend not configured:** check `js/config.js`, then hard refresh.
- **Admin login says credentials not initialized:** run the generated credential SQL in Supabase.
- **Function unavailable:** deploy `admin-api` and check Supabase Edge Function logs.
- **Image upload fails:** confirm bucket `portfolio-media` exists, the Edge Function has service-role access, file is JPG/PNG/WebP and under 8 MB.
- **Public page shows placeholders:** check Supabase URL/anon key and browser console; confirm migration and seed rows were run.

## Official references

- GitHub Pages: https://docs.github.com/pages
- Supabase JavaScript: https://supabase.com/docs/reference/javascript/introduction
- Supabase Edge Functions: https://supabase.com/docs/guides/functions
- Supabase RLS: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase Storage: https://supabase.com/docs/guides/storage


## Existing Supabase project (already configured)

This package is prefilled with the project's Supabase URL and publishable key. The Edge Function expects the server-side secret named `SERVICE_ROLE_KEY` and the custom `ADMIN_SESSION_SECRET`. Do not put either secret in `js/config.js` or upload them to GitHub.
