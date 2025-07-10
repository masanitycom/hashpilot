"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { supabase } from "@/lib/supabase"
import { Loader2, Database, CheckCircle, XCircle } from "lucide-react"

export default function FixRLSPage() {
  const [loading, setLoading] = useState(false)
  const [results, setResults] = useState<any[]>([])
  const [error, setError] = useState("")
  const [isAdmin, setIsAdmin] = useState(false)

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

  const fixRLSPolicies = async () => {
    if (!isAdmin) {
      setError("管理者権限が必要です")
      return
    }

    setLoading(true)
    setError("")
    setResults([])

    try {
      // 1. Check current RLS status
      const { data: rlsStatus, error: rlsError } = await supabase
        .from('pg_tables')
        .select('tablename, rowsecurity')
        .eq('tablename', 'user_daily_profit')

      if (rlsError) throw rlsError
      setResults(prev => [...prev, { step: "RLS Status Check", data: rlsStatus }])

      // 2. Enable RLS (this will be handled by the function)
      // 3. Drop existing policies and create new ones
      const { data: policyResult, error: policyError } = await supabase.rpc('fix_user_daily_profit_rls')
      
      if (policyError) throw policyError
      setResults(prev => [...prev, { step: "RLS Policy Fix", data: policyResult }])

      // 4. Test the fix - try to query user_daily_profit
      const { data: testQuery, error: testError } = await supabase
        .from('user_daily_profit')
        .select('user_id, date, daily_profit')
        .limit(5)

      if (testError) {
        setResults(prev => [...prev, { step: "Test Query", error: testError.message }])
      } else {
        setResults(prev => [...prev, { step: "Test Query Success", data: testQuery }])
      }

    } catch (err: any) {
      console.error("RLS Fix Error:", err)
      setError(err.message || "RLS修正中にエラーが発生しました")
    } finally {
      setLoading(false)
    }
  }

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-gray-900 text-white p-6">
        <Card className="bg-gray-800 border-gray-700">
          <CardContent className="p-6">
            <p className="text-red-400">管理者権限が必要です</p>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-900 text-white p-6">
      <div className="max-w-6xl mx-auto space-y-6">
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white flex items-center gap-2">
              <Database className="h-5 w-5" />
              RLS Policy Fix for user_daily_profit
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex gap-4">
              <Button 
                onClick={fixRLSPolicies}
                disabled={loading}
                className="bg-blue-600 hover:bg-blue-700"
              >
                {loading && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
                Fix RLS Policies
              </Button>
            </div>

            {error && (
              <div className="p-4 bg-red-900/50 border border-red-500 rounded">
                <p className="text-red-300">{error}</p>
              </div>
            )}

            {results.length > 0 && (
              <div className="space-y-4">
                <h3 className="text-lg font-semibold">実行結果</h3>
                {results.map((result, index) => (
                  <Card key={index} className="bg-gray-700 border-gray-600">
                    <CardHeader className="pb-2">
                      <CardTitle className="text-sm flex items-center gap-2">
                        {result.error ? 
                          <XCircle className="h-4 w-4 text-red-400" /> : 
                          <CheckCircle className="h-4 w-4 text-green-400" />
                        }
                        {result.step}
                      </CardTitle>
                    </CardHeader>
                    <CardContent>
                      {result.error ? (
                        <p className="text-red-300 text-sm">{result.error}</p>
                      ) : (
                        <pre className="text-xs text-gray-300 bg-gray-800 p-2 rounded overflow-auto">
                          {JSON.stringify(result.data, null, 2)}
                        </pre>
                      )}
                    </CardContent>
                  </Card>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}