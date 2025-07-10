-- Create function to fix user_daily_profit RLS policies

CREATE OR REPLACE FUNCTION fix_user_daily_profit_rls()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result_message TEXT := '';
BEGIN
  -- Enable RLS on user_daily_profit table
  BEGIN
    ALTER TABLE user_daily_profit ENABLE ROW LEVEL SECURITY;
    result_message := result_message || 'RLS enabled on user_daily_profit table. ';
  EXCEPTION WHEN OTHERS THEN
    result_message := result_message || 'RLS already enabled. ';
  END;

  -- Drop existing policies
  BEGIN
    DROP POLICY IF EXISTS "Users can view own profit data" ON user_daily_profit;
    DROP POLICY IF EXISTS "Allow users to view their own profit data" ON user_daily_profit;
    DROP POLICY IF EXISTS "Enable read access for authenticated users" ON user_daily_profit;
    DROP POLICY IF EXISTS "Admins can view all profit data" ON user_daily_profit;
    result_message := result_message || 'Existing policies dropped. ';
  EXCEPTION WHEN OTHERS THEN
    result_message := result_message || 'Policy drop warning: ' || SQLERRM || '. ';
  END;

  -- Create new policy for users to view their own data
  BEGIN
    CREATE POLICY "Users can view own profit data" ON user_daily_profit
    FOR SELECT
    TO authenticated
    USING (
      user_id IN (
        SELECT user_id 
        FROM users 
        WHERE id = auth.uid()
      )
    );
    result_message := result_message || 'User view policy created. ';
  EXCEPTION WHEN OTHERS THEN
    result_message := result_message || 'User policy error: ' || SQLERRM || '. ';
  END;

  -- Create admin policy
  BEGIN
    CREATE POLICY "Admins can view all profit data" ON user_daily_profit
    FOR ALL
    TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM admins 
        WHERE email = auth.jwt()->>'email' 
        AND is_active = true
      )
    );
    result_message := result_message || 'Admin policy created. ';
  EXCEPTION WHEN OTHERS THEN
    result_message := result_message || 'Admin policy error: ' || SQLERRM || '. ';
  END;

  RETURN result_message || 'RLS fix completed successfully.';
EXCEPTION WHEN OTHERS THEN
  RETURN 'Error: ' || SQLERRM;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION fix_user_daily_profit_rls() TO anon;
GRANT EXECUTE ON FUNCTION fix_user_daily_profit_rls() TO authenticated;