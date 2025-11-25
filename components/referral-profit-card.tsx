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
      console.log('🚀 ReferralProfitCard: fetchReferralProfit started for userId:', userId)

      // 昨日の日付を取得（7/16）
      const yesterday = new Date()
      yesterday.setDate(yesterday.getDate() - 1)
      const yesterdayStr = yesterday.toISOString().split('T')[0]
      console.log('📅 Target date - Yesterday:', yesterdayStr)

      // 今月の開始日と終了日を取得
      const now = new Date()
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0]
      const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString().split('T')[0]
      console.log('📅 Month range:', monthStart, 'to', monthEnd)

      // 紹介報酬率の定義
      const level1Rate = 0.20 // 20%
      const level2Rate = 0.10 // 10%
      const level3Rate = 0.05 // 5%

      // 各レベルの実際の紹介者IDを取得
      console.log('🔍 Fetching referral user IDs...')
      const level1UserIds = await getDirectReferrals(userId)
      const level2UserIds = await getLevel2Referrals(userId)
      const level3UserIds = await getLevel3Referrals(userId)

      console.log('Level 1 referrals:', level1UserIds)
      console.log('Level 2 referrals:', level2UserIds)
      console.log('Level 3 referrals:', level3UserIds)

          // 実際の紹介報酬データをuser_referral_profitテーブルから取得
      const level1Profits = await getActualReferralProfits(userId, 1, monthStart, monthEnd, yesterdayStr)
      const level2Profits = await getActualReferralProfits(userId, 2, monthStart, monthEnd, yesterdayStr)
      const level3Profits = await getActualReferralProfits(userId, 3, monthStart, monthEnd, yesterdayStr)

      console.log('Level 1 referral profits:', level1Profits)
      console.log('Level 2 referral profits:', level2Profits)
      console.log('Level 3 referral profits:', level3Profits)

      // 実際に記録された紹介報酬をそのまま使用（計算不要）
      const level1Yesterday = level1Profits.yesterday
      const level1Monthly = level1Profits.monthly

      const level2Yesterday = level2Profits.yesterday
      const level2Monthly = level2Profits.monthly

      const level3Yesterday = level3Profits.yesterday
      const level3Monthly = level3Profits.monthly

      console.log('Actual referral profits from DB:')
      console.log('L1 Yesterday:', level1Yesterday, 'L1 Monthly:', level1Monthly)
      console.log('L2 Yesterday:', level2Yesterday, 'L2 Monthly:', level2Monthly)
      console.log('L3 Yesterday:', level3Yesterday, 'L3 Monthly:', level3Monthly)

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

  // user_referral_profitテーブルから実際の紹介報酬を取得
  const getActualReferralProfits = async (userId: string, level: number, monthStart: string, monthEnd: string, yesterdayStr: string) => {
    console.log(`📊 Fetching actual referral profits for level ${level}...`)

    const { data, error } = await supabase
      .from('user_referral_profit')
      .select('date, profit_amount')
      .eq('user_id', userId)
      .eq('referral_level', level)
      .gte('date', monthStart)
      .lte('date', monthEnd)

    if (error) {
      console.error(`❌ Error fetching level ${level} referral profits:`, error)
      return { yesterday: 0, monthly: 0 }
    }

    console.log(`✅ Level ${level} referral profit records:`, data)

    let yesterday = 0
    let monthly = 0

    if (data && data.length > 0) {
      data.forEach(row => {
        const profit = parseFloat(row.profit_amount) || 0

        // 昨日の利益
        if (row.date === yesterdayStr) {
          yesterday += profit
        }

        // 月間累計利益
        monthly += profit
      })
    }

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
          Level1-3投資額: ${(totalLevel3Investment || 0).toLocaleString()}
        </div>

        {/* 月末集計後に表示されます */}
        <div className="text-center py-8 space-y-3">
          <div className="text-sm text-muted-foreground mb-2">
            ※ 紹介報酬は月末の集計後に表示されます
          </div>
          <div className="text-4xl font-bold text-muted-foreground">
            --
          </div>
          <div className="text-xs text-gray-500">
            月末に自動で集計されます
          </div>
        </div>

        {error && (
          <p className="text-xs text-red-400 mt-2">{error}</p>
        )}
      </CardContent>
    </Card>
  )
}
