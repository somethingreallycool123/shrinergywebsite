-- Add Paddle ID columns to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS paddle_customer_id TEXT,
ADD COLUMN IF NOT EXISTS paddle_subscription_id TEXT;

-- Create index for faster lookups since we query by these in webhook
CREATE INDEX IF NOT EXISTS idx_profiles_paddle_customer_id ON profiles(paddle_customer_id);
