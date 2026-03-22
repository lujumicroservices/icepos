# First-time Supabase setup

1. **Create a Supabase project** at [supabase.com](https://supabase.com).

2. **Apply the database schema** (tables, RLS, realtime). The Flutter app **cannot** create tables with the **anon** key. Run the SQL migrations in order from this folder (`migrations/*.sql`) using:
   - **Supabase Dashboard → SQL Editor** (paste and run each file in numeric order), or  
   - **Supabase CLI**: `supabase db push` / `supabase migration up` (if you use the CLI workflow).

3. **Get credentials**: Project **Settings → API**  
   - **Project URL** → `SUPABASE_URL`  
   - **anon public** key → `SUPABASE_ANON_KEY`

4. **On a new device / first install**, the ICE POS app can show a **setup screen** where you paste URL + anon key. They are stored on the device (SharedPreferences).  
   Alternatively, add them to `ice_pos/.env` before building (developer workflow).

5. **First data**: After connecting, the app runs **sync from cloud**. If the cloud has no categories yet, use **Load menu from JSON** in the app drawer on the first device, then sync/push to cloud as you already do.

See also `README_RECREATE.md` in this folder if you need to recreate the project from scratch.
