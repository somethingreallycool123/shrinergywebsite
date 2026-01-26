-- Artemis Rate Limiting & Subscription Schema Migration
-- Run this in Supabase SQL Editor
-- =====================================================

-- 1. Add subscription fields to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS subscription_status TEXT DEFAULT 'free',
ADD COLUMN IF NOT EXISTS subscription_ends_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS razorpay_customer_id TEXT,
ADD COLUMN IF NOT EXISTS razorpay_subscription_id TEXT;

-- Create index for subscription lookups
CREATE INDEX IF NOT EXISTS idx_profiles_subscription ON profiles(subscription_status);

-- 2. Monthly usage tracking table
CREATE TABLE IF NOT EXISTS usage_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    month TEXT NOT NULL,  -- Format: '2025-01'
    tokens_used BIGINT DEFAULT 0,
    voice_minutes_used INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, month)
);

-- Enable RLS
ALTER TABLE usage_tracking ENABLE ROW LEVEL SECURITY;

-- Policies for usage_tracking
CREATE POLICY "Users can view own usage" ON usage_tracking
    FOR SELECT USING (auth.uid() = user_id);
    
CREATE POLICY "Service role full access on usage" ON usage_tracking
    FOR ALL USING (auth.role() = 'service_role');

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_usage_user_month ON usage_tracking(user_id, month);

-- 3. Function to increment token usage (atomic operation)
CREATE OR REPLACE FUNCTION increment_tokens(p_user_id UUID, p_tokens BIGINT)
RETURNS BIGINT AS $$
DECLARE
    current_month TEXT := to_char(NOW(), 'YYYY-MM');
    new_total BIGINT;
BEGIN
    INSERT INTO usage_tracking (user_id, month, tokens_used)
    VALUES (p_user_id, current_month, p_tokens)
    ON CONFLICT (user_id, month)
    DO UPDATE SET 
        tokens_used = usage_tracking.tokens_used + EXCLUDED.tokens_used,
        updated_at = NOW()
    RETURNING tokens_used INTO new_total;
    
    RETURN new_total;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Function to increment voice minutes (atomic operation)
CREATE OR REPLACE FUNCTION increment_voice_minutes(p_user_id UUID, p_minutes INTEGER)
RETURNS INTEGER AS $$
DECLARE
    current_month TEXT := to_char(NOW(), 'YYYY-MM');
    new_total INTEGER;
BEGIN
    INSERT INTO usage_tracking (user_id, month, voice_minutes_used)
    VALUES (p_user_id, current_month, p_minutes)
    ON CONFLICT (user_id, month)
    DO UPDATE SET 
        voice_minutes_used = usage_tracking.voice_minutes_used + EXCLUDED.voice_minutes_used,
        updated_at = NOW()
    RETURNING voice_minutes_used INTO new_total;
    
    RETURN new_total;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION increment_tokens(UUID, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_voice_minutes(UUID, INTEGER) TO authenticated;
