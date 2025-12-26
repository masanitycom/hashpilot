"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Textarea } from "@/components/ui/textarea"
import { supabase } from "@/lib/supabase"
import { Database, Play, Shield } from "lucide-react"

export default function ExecuteSQLPage() {
  const [isAdmin, setIsAdmin] = useState(false)
  const [loading, setLoading] = useState(false)
  const [result, setResult] = useState("")
  const [error, setError] = useState("")
  
  const rlsFixSQL = `-- Create function to fix user_daily_profit RLS policies

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
GRANT EXECUTE ON FUNCTION fix_user_daily_profit_rls() TO authenticated;`

  useEffect(() => {
    checkAdminStatus()
  }, [])

  const checkAdminStatus = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      const { data: adminCheck } = await supabase.rpc('is_admin', {
        p_email: user.email
      })
      setIsAdmin(adminCheck === true)
    } catch (err) {
      console.error('Admin check error:', err)
    }
  }

  const executeSQL = async () => {
    setLoading(true)
    setError("")
    setResult("")

    try {
      // This is a workaround - we'll use the SQL editor in Supabase dashboard
      setResult("To execute this SQL, please:\n\n1. Go to your Supabase Dashboard\n2. Navigate to SQL Editor\n3. Paste the SQL code below\n4. Click 'Run'\n\nSQL Code to execute:\n\n" + rlsFixSQL)
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-black text-white p-6">
        <Card className="bg-gray-800 border-gray-700">
          <CardContent className="p-6">
            <p className="text-red-400">管理者権限が必要です</p>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-black text-white p-6">
      <div className="max-w-6xl mx-auto space-y-6">
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white flex items-center gap-2">
              <Database className="h-5 w-5" />
              RLS Function Creation
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <Button 
              onClick={executeSQL}
              disabled={loading}
              className="bg-blue-600 hover:bg-blue-700"
            >
              <Shield className="h-4 w-4 mr-2" />
              Show SQL Instructions
            </Button>

            {result && (
              <div className="space-y-4">
                <pre className="text-xs text-gray-300 bg-black p-4 rounded overflow-auto whitespace-pre-wrap">
                  {result}
                </pre>
              </div>
            )}

            {error && (
              <div className="p-4 bg-red-900/50 border border-red-500 rounded">
                <p className="text-red-300">{error}</p>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}