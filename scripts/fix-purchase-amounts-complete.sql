-- Fix all purchase amounts to be in $1000 increments
-- Remove purchase_type column references

-- First, update all existing purchases to be $1000 increments
UPDATE purchases 
SET 
  amount_usd = 1000,
  investment_amount = 1000,
  fee_amount = 100
WHERE amount_usd > 1000;

-- Update user total_purchases to reflect $1000 increments only
UPDATE users 
SET total_purchases = (
  SELECT COALESCE(SUM(investment_amount), 0)
  FROM purchases 
  WHERE purchases.user_id = users.id
  AND admin_approved = true
);

-- Create or replace the referral tree function
CREATE OR REPLACE FUNCTION get_referral_tree(root_user_id TEXT)
RETURNS TABLE (
  user_id TEXT,
  email TEXT,
  full_name TEXT,
  level INTEGER,
  total_purchases NUMERIC,
  referral_count INTEGER,
  created_at TIMESTAMP WITH TIME ZONE
) 
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH RECURSIVE referral_tree AS (
    -- Base case: root user
    SELECT 
      u.user_id,
      u.email,
      u.full_name,
      1 as level,
      u.total_purchases,
      0 as referral_count,
      u.created_at
    FROM users u
    WHERE u.user_id = root_user_id
    
    UNION ALL
    
    -- Recursive case: find referrals up to 3 levels
    SELECT 
      u.user_id,
      u.email,
      u.full_name,
      rt.level + 1,
      u.total_purchases,
      0 as referral_count,
      u.created_at
    FROM users u
    INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
    WHERE rt.level < 3
  )
  SELECT * FROM referral_tree ORDER BY level, created_at;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO anon;

-- Create monthly_rewards table if it doesn't exist
CREATE TABLE IF NOT EXISTS monthly_rewards (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  reward_amount NUMERIC DEFAULT 0,
  reward_month DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE monthly_rewards ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view own monthly rewards" ON monthly_rewards
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage monthly rewards" ON monthly_rewards
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM admins 
      WHERE user_id = auth.uid() 
      AND is_active = true
    )
  );
