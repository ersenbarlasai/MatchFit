-- ============================================================
-- Supabase Storage: avatars bucket + RLS
-- Supabase Dashboard > SQL Editor > Run this
-- ============================================================

-- 1. Bucket oluştur (public = URL ile doğrudan erişilebilir)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  5242880,  -- 5 MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- 2. Kullanıcı kendi klasörüne yükleyebilir
CREATE POLICY "Users can upload their own avatar"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- 3. Kullanıcı kendi avatarını güncelleyebilir
CREATE POLICY "Users can update their own avatar"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- 4. Herkes avatarları okuyabilir (public bucket)
CREATE POLICY "Anyone can read avatars"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'avatars');

-- 5. Profiles tablosuna avatar_url sütunu ekle (yoksa)
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS avatar_url TEXT;
