-- ============================================
-- SUPABASE ADMIN POLICIES SETUP
-- ============================================
-- Run these SQL commands in your Supabase SQL Editor
-- to allow admins to see and manage all guides and appointments

-- ============================================
-- 1. GUIDES TABLE POLICIES
-- ============================================

-- First, make sure guides table has a 'status' column
-- If it doesn't exist, run this:
-- ALTER TABLE guides ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';

-- Allow admins to read ALL guides (for moderation)
CREATE POLICY "Admins can read all guides"
ON guides
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'admin'
  )
);

-- Allow admins to update ALL guides (approve/reject)
CREATE POLICY "Admins can update all guides"
ON guides
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'admin'
  )
);

-- Allow regular users to read only approved guides (or null status for backward compatibility)
CREATE POLICY "Users can read approved guides"
ON guides
FOR SELECT
USING (
  status = 'approved' OR status IS NULL
);

-- Allow users to create guides (defaults to pending)
CREATE POLICY "Users can create guides"
ON guides
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own guides
CREATE POLICY "Users can update own guides"
ON guides
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Allow users to delete their own guides
CREATE POLICY "Users can delete own guides"
ON guides
FOR DELETE
USING (auth.uid() = user_id);

-- ============================================
-- 2. APPOINTMENTS TABLE POLICIES
-- ============================================

-- Allow admins to read ALL appointments (for moderation)
CREATE POLICY "Admins can read all appointments"
ON appointment
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'admin'
  )
);

-- Allow admins to update ALL appointments (approve/reject)
CREATE POLICY "Admins can update all appointments"
ON appointment
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'admin'
  )
);

-- Allow users to read their own appointments
CREATE POLICY "Users can read own appointments"
ON appointment
FOR SELECT
USING (auth.uid() = user_id);

-- Allow users to create appointments
CREATE POLICY "Users can create appointments"
ON appointment
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own appointments
CREATE POLICY "Users can update own appointments"
ON appointment
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Allow users to delete their own appointments
CREATE POLICY "Users can delete own appointments"
ON appointment
FOR DELETE
USING (auth.uid() = user_id);

-- ============================================
-- 3. VERIFY YOUR SETUP
-- ============================================
-- After running these policies, verify:
-- 1. Your profiles table has a 'role' column with values 'admin' or 'member'
-- 2. At least one user has role = 'admin' in the profiles table
-- 3. The guides table has a 'status' column (TEXT type)
-- 4. The appointment table has a 'status' column (TEXT type)

-- To check if a user is admin:
-- SELECT role FROM profiles WHERE id = 'user-uuid-here';

-- To set a user as admin:
-- UPDATE profiles SET role = 'admin' WHERE id = 'user-uuid-here';

