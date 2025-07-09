-- Add address columns to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS reward_address_bep20 TEXT,
ADD COLUMN IF NOT EXISTS nft_address TEXT,
ADD COLUMN IF NOT EXISTS nft_sent BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS nft_sent_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS nft_sent_by TEXT;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_users_reward_address ON users(reward_address_bep20);
CREATE INDEX IF NOT EXISTS idx_users_nft_address ON users(nft_address);
CREATE INDEX IF NOT EXISTS idx_users_nft_sent ON users(nft_sent);

-- Create function to update user addresses (admin use)
CREATE OR REPLACE FUNCTION update_user_addresses(
  p_user_id TEXT,
  p_reward_address TEXT DEFAULT NULL,
  p_nft_address TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE users 
  SET 
    reward_address_bep20 = COALESCE(p_reward_address, reward_address_bep20),
    nft_address = COALESCE(p_nft_address, nft_address),
    updated_at = NOW()
  WHERE user_id = p_user_id;
  
  RETURN FOUND;
END;
$$;

-- Create function to mark NFT as sent
CREATE OR REPLACE FUNCTION mark_nft_sent(
  p_user_id TEXT,
  p_admin_id TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE users 
  SET 
    nft_sent = TRUE,
    nft_sent_at = NOW(),
    nft_sent_by = p_admin_id,
    updated_at = NOW()
  WHERE user_id = p_user_id;
  
  RETURN FOUND;
END;
$$;

-- Create monthly_rewards table if it doesn't exist
CREATE TABLE IF NOT EXISTS monthly_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  reward_amount DECIMAL(15,2) DEFAULT 0,
  reward_month INTEGER NOT NULL,
  reward_year INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, reward_month, reward_year)
);

-- Create index for monthly_rewards
CREATE INDEX IF NOT EXISTS idx_monthly_rewards_user_id ON monthly_rewards(user_id);
CREATE INDEX IF NOT EXISTS idx_monthly_rewards_date ON monthly_rewards(reward_year, reward_month);

-- Create simple referral tree function
CREATE OR REPLACE FUNCTION get_referral_tree(root_user_id TEXT)
RETURNS TABLE(
  user_id TEXT,
  email TEXT,
  full_name TEXT,
  coinw_uid TEXT,
  level_num INTEGER,
  path TEXT,
  referrer_id TEXT,
  total_investment DECIMAL,
  direct_referrals INTEGER,
  total_referrals INTEGER,
  created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH RECURSIVE referral_tree AS (
    -- Level 1: Direct referrals
    SELECT 
      u.user_id,
      u.email,
      u.full_name,
      u.coinw_uid,
      1 as level_num,
      ROW_NUMBER() OVER (ORDER BY u.created_at)::TEXT as path,
      u.referrer_user_id as referrer_id,
      COALESCE(u.total_purchases, 1000)::DECIMAL as total_investment,
      0 as direct_referrals,
      0 as total_referrals,
      u.created_at
    FROM users u
    WHERE u.referrer_user_id = root_user_id
    
    UNION ALL
    
    -- Recursive: Next levels
    SELECT 
      u.user_id,
      u.email,
      u.full_name,
      u.coinw_uid,
      rt.level_num + 1,
      rt.path || '.' || ROW_NUMBER() OVER (PARTITION BY rt.user_id ORDER BY u.created_at)::TEXT,
      u.referrer_user_id,
      COALESCE(u.total_purchases, 1000)::DECIMAL,
      0,
      0,
      u.created_at
    FROM users u
    INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
    WHERE rt.level_num < 10 -- Limit depth to prevent infinite recursion
  )
  SELECT * FROM referral_tree
  ORDER BY level_num, path;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION update_user_addresses(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION mark_nft_sent(TEXT, TEXT) TO authenticated;

-- Insert some sample monthly rewards for testing
INSERT INTO monthly_rewards (user_id, reward_amount, reward_month, reward_year)
SELECT 
  user_id, 
  (RANDOM() * 1000)::DECIMAL(15,2), 
  EXTRACT(MONTH FROM NOW())::INTEGER,
  EXTRACT(YEAR FROM NOW())::INTEGER
FROM users 
WHERE total_purchases > 0
ON CONFLICT (user_id, reward_month, reward_year) DO NOTHING;
