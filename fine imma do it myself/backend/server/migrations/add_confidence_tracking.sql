-- Migration: Add confidence tracking to temporal memories
-- Run this in Supabase SQL editor

-- Add date_confidence column (high/medium/low)
ALTER TABLE user_temporal_memories 
ADD COLUMN IF NOT EXISTS date_confidence TEXT DEFAULT 'medium';

-- Add asked_for_clarification tracking (prevents asking twice)
ALTER TABLE user_temporal_memories 
ADD COLUMN IF NOT EXISTS asked_for_clarification BOOLEAN DEFAULT FALSE;

-- Create index for faster queries on low-confidence items
CREATE INDEX IF NOT EXISTS idx_temporal_needs_clarification 
ON user_temporal_memories(user_id, date_confidence, asked_for_clarification) 
WHERE status = 'active' AND date_confidence IN ('low', 'medium') AND asked_for_clarification = FALSE;
