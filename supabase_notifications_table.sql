-- ============================================
-- SUPABASE NOTIFICATIONS TABLE SETUP
-- ============================================
-- Run this SQL in your Supabase SQL Editor to create the notifications table

-- Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL, -- e.g., 'appointment_status'
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  appointment_id TEXT, -- Optional: reference to appointment
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(user_id, is_read);

-- Enable Row Level Security
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only read their own notifications
CREATE POLICY "Users can read own notifications"
ON notifications
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can update their own notifications (to mark as read)
CREATE POLICY "Users can update own notifications"
ON notifications
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: System can insert notifications (for admin actions)
-- Note: This allows any authenticated user to insert, but in practice only admins will
-- You might want to restrict this further based on your needs
CREATE POLICY "Authenticated users can create notifications"
ON notifications
FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

