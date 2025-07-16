"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Users, TrendingUp, Loader2 } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface ReferralProfitCardProps {
  userId: string
  level1Investment: number
  level2Investment: number
  level3Investment: number
}

interface ReferralProfitData {
  yesterdayProfit: number
  monthlyProfit: number
  breakdown: {
    level1Yesterday: number
    level2Yesterday: number
    level3Yesterday: number
    level1Monthly: number
    level2Monthly: number
    level3Monthly: number
  }
}

export function ReferralProfitCard({ 
  userId, 
  level1Investment, 
  level2Investment, 
  level3Investment 
}: ReferralProfitCardProps) {
  const [profitData, setProfitData] = useState<ReferralProfitData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")

  useEffect(() => {
    if (userId) {
      fetchReferralProfit()
    }
  }, [userId, level1Investment, level2Investment, level3Investment])

  const fetchReferralProfit = async () => {
    try {
      setLoading(true)
      setError("")

      // 昨日の日付を取得（7/16）
      const yesterday = new Date()
      yesterday.setDate(yesterday.getDate() - 1)
      const yesterdayStr = yesterday.toISOString().split('T')[0]

      // 今月の開始日と終了日を取得
      const now = new Date()
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0]
      const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString().split('T')[0]

      // 紹介報酬率の定義
      const level1Rate = 0.20 // 20%
      const level2Rate = 0.10 // 10%
      const level3Rate = 0.05 // 5%

      // 既存の紹介報酬データを取得
      const { data: referralData, error: referralError } = await supabase
        .from('user_daily_profit')
        .select('date, referral_profit')
        .eq('user_id', userId)
        .gte('date', monthStart)
        .lte('date', monthEnd)

      if (referralError) {
        throw referralError
      }

      let totalYesterdayReferral = 0
      let totalMonthlyReferral = 0

      if (referralData) {
        referralData.forEach(row => {
          const profit = parseFloat(row.referral_profit) || 0
          
          if (row.date === '2025-07-16') {
            totalYesterdayReferral += profit
          }
          
          totalMonthlyReferral += profit
        })
      }

      // 紹介報酬率に基づいて分配（20%:10%:5% = 4:2:1の比率）
      const totalRatio = 4 + 2 + 1 // 7
      
      const level1Yesterday = totalYesterdayReferral * (4 / totalRatio)  // 20%分
      const level1Monthly = totalMonthlyReferral * (4 / totalRatio)
      
      const level2Yesterday = totalYesterdayReferral * (2 / totalRatio)  // 10%分
      const level2Monthly = totalMonthlyReferral * (2 / totalRatio)
      
      const level3Yesterday = totalYesterdayReferral * (1 / totalRatio)  // 5%分
      const level3Monthly = totalMonthlyReferral * (1 / totalRatio)

      const totalYesterdayReferralProfit = level1Yesterday + level2Yesterday + level3Yesterday
      const totalMonthlyReferralProfit = level1Monthly + level2Monthly + level3Monthly

      setProfitData({
        yesterdayProfit: totalYesterdayReferralProfit,
        monthlyProfit: totalMonthlyReferralProfit,
        breakdown: {
          level1Yesterday,
          level2Yesterday,
          level3Yesterday,
          level1Monthly,
          level2Monthly,
          level3Monthly
        }
      })

    } catch (err: any) {
      console.error("Referral profit fetch error:", err)
      setError("紹介報酬データの取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  // 指定されたユーザーIDリストの利益を取得
  const getReferralProfits = async (userIds: string[], monthStart: string, monthEnd: string) => {
    if (userIds.length === 0) {
      return { yesterday: 0, monthly: 0 }
    }

    const { data, error } = await supabase
      .from('user_daily_profit')
      .select('date, daily_profit, user_id')
      .in('user_id', userIds)
      .gte('date', monthStart)
      .lte('date', monthEnd)

    if (error) {
      console.error('Error fetching referral profits:', error)
      return { yesterday: 0, monthly: 0 }
    }

    console.log('Raw data for userIds:', userIds)
    console.log('Raw data result:', data)

    let yesterday = 0
    let monthly = 0

    data.forEach(row => {
      const profit = parseFloat(row.daily_profit) || 0
      
      // 昨日の利益（7/16）
      if (row.date === '2025-07-16') {
        yesterday += profit
      }
      
      // 月間累計利益
      monthly += profit
    })

    return { yesterday, monthly }
  }

  // 直接紹介者のIDを取得
  const getDirectReferrals = async (userId: string): Promise<string[]> => {
    const { data, error } = await supabase
      .from('users')
      .select('user_id')
      .eq('referrer_user_id', userId)

    if (error) {
      console.error('Error fetching direct referrals:', error)
      return []
    }

    return data.map(user => user.user_id)
  }

  // Level2紹介者のIDを取得
  const getLevel2Referrals = async (userId: string): Promise<string[]> => {
    const level1Ids = await getDirectReferrals(userId)
    if (level1Ids.length === 0) return []

    const { data, error } = await supabase
      .from('users')
      .select('user_id')
      .in('referrer_user_id', level1Ids)

    if (error) {
      console.error('Error fetching level2 referrals:', error)
      return []
    }

    return data.map(user => user.user_id)
  }

  // Level3紹介者のIDを取得
  const getLevel3Referrals = async (userId: string): Promise<string[]> => {
    const level2Ids = await getLevel2Referrals(userId)
    if (level2Ids.length === 0) return []

    const { data, error } = await supabase
      .from('users')
      .select('user_id')
      .in('referrer_user_id', level2Ids)

    if (error) {
      console.error('Error fetching level3 referrals:', error)
      return []
    }

    return data.map(user => user.user_id)
  }

  if (loading) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardHeader className="pb-3">
          <CardTitle className="text-gray-300 text-sm font-medium">Level3紹介報酬</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-center space-x-2">
            <Loader2 className="h-5 w-5 text-purple-400 animate-spin" />
            <span className="text-sm text-gray-400">読み込み中...</span>
          </div>
        </CardContent>
      </Card>
    )
  }

  const totalLevel3Investment = level1Investment + level2Investment + level3Investment

  return (
    <Card className="bg-gray-800 border-gray-700">
      <CardHeader className="pb-3">
        <CardTitle className="text-gray-300 text-sm font-medium flex items-center gap-2">
          <Users className="h-4 w-4 text-purple-400" />
          Level3紹介報酬
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="text-xs text-gray-400 mb-3">
          Level1-3投資額: ${totalLevel3Investment.toLocaleString()}
        </div>
        
        {/* 昨日の紹介報酬 */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-xs text-gray-400">昨日の報酬</span>
            <div className="flex items-center space-x-1">
              <TrendingUp className="h-3 w-3 text-purple-400" />
              <span className={`text-sm font-semibold ${
                (profitData?.yesterdayProfit || 0) >= 0 ? "text-purple-400" : "text-red-400"
              }`}>
                ${(profitData?.yesterdayProfit || 0).toFixed(3)}
              </span>
            </div>
          </div>
          
          {/* レベル別内訳（昨日） */}
          {profitData && totalLevel3Investment > 0 && (
            <div className="text-xs space-y-1 ml-4 opacity-75">
              {level1Investment > 0 && (
                <div className="flex justify-between">
                  <span className="text-green-400">L1(20%):</span>
                  <span className="text-green-400">${profitData.breakdown.level1Yesterday.toFixed(3)}</span>
                </div>
              )}
              {level2Investment > 0 && (
                <div className="flex justify-between">
                  <span className="text-blue-400">L2(10%):</span>
                  <span className="text-blue-400">${profitData.breakdown.level2Yesterday.toFixed(3)}</span>
                </div>
              )}
              {level3Investment > 0 && (
                <div className="flex justify-between">
                  <span className="text-purple-400">L3(5%):</span>
                  <span className="text-purple-400">${profitData.breakdown.level3Yesterday.toFixed(3)}</span>
                </div>
              )}
            </div>
          )}
        </div>

        {/* 今月の累計紹介報酬 */}
        <div className="space-y-2 border-t border-gray-600 pt-3">
          <div className="flex items-center justify-between">
            <span className="text-xs text-gray-400">今月累計</span>
            <div className="flex items-center space-x-1">
              <TrendingUp className="h-3 w-3 text-orange-400" />
              <span className={`text-lg font-bold ${
                (profitData?.monthlyProfit || 0) >= 0 ? "text-orange-400" : "text-red-400"
              }`}>
                ${(profitData?.monthlyProfit || 0).toFixed(3)}
              </span>
            </div>
          </div>

          {/* レベル別内訳（今月） */}
          {profitData && totalLevel3Investment > 0 && (
            <div className="text-xs space-y-1 ml-4 opacity-75">
              {level1Investment > 0 && (
                <div className="flex justify-between">
                  <span className="text-green-400">L1(20%):</span>
                  <span className="text-green-400">${profitData.breakdown.level1Monthly.toFixed(3)}</span>
                </div>
              )}
              {level2Investment > 0 && (
                <div className="flex justify-between">
                  <span className="text-blue-400">L2(10%):</span>
                  <span className="text-blue-400">${profitData.breakdown.level2Monthly.toFixed(3)}</span>
                </div>
              )}
              {level3Investment > 0 && (
                <div className="flex justify-between">
                  <span className="text-purple-400">L3(5%):</span>
                  <span className="text-purple-400">${profitData.breakdown.level3Monthly.toFixed(3)}</span>
                </div>
              )}
            </div>
          )}
        </div>

        {error && (
          <p className="text-xs text-red-400 mt-2">{error}</p>
        )}
      </CardContent>
    </Card>
  )
}