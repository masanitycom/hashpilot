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

      // 各レベルの紹介者の個人利益を取得し、報酬率を適用
      const level1Profits = await getReferralProfits(level1UserIds, monthStart, monthEnd, yesterdayStr)
      const level2Profits = await getReferralProfits(level2UserIds, monthStart, monthEnd, yesterdayStr)
      const level3Profits = await getReferralProfits(level3UserIds, monthStart, monthEnd, yesterdayStr)

      console.log('Level 1 profits:', level1Profits)
      console.log('Level 2 profits:', level2Profits)
      console.log('Level 3 profits:', level3Profits)

      // 正しい紹介報酬計算: 各レベルの個人利益 × 報酬率
      const level1Yesterday = level1Profits.yesterday * level1Rate
      const level1Monthly = level1Profits.monthly * level1Rate
      
      const level2Yesterday = level2Profits.yesterday * level2Rate
      const level2Monthly = level2Profits.monthly * level2Rate
      
      const level3Yesterday = level3Profits.yesterday * level3Rate
      const level3Monthly = level3Profits.monthly * level3Rate

      console.log('Calculated referral profits:')
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

  // 指定されたユーザーIDリストの利益を取得（運用開始日チェック付き）
  const getReferralProfits = async (userIds: string[], monthStart: string, monthEnd: string, yesterdayStr: string) => {
    if (userIds.length === 0) {
      return { yesterday: 0, monthly: 0 }
    }

    // NFT承認済みかつ実際に運用開始しているユーザーのみフィルター
    console.log('🔍 Checking operational status for users:', userIds)

    // 今日の日付を取得（運用開始日との比較用）
    const today = new Date().toISOString().split('T')[0]

    const { data: usersData, error: usersError } = await supabase
      .from('users')
      .select(`
        user_id,
        has_approved_nft,
        operation_start_date,
        affiliate_cycle!inner(total_nft_count)
      `)
      .in('user_id', userIds)
      .eq('has_approved_nft', true)
      .gt('affiliate_cycle.total_nft_count', 0)
      .not('operation_start_date', 'is', null)
      .lte('operation_start_date', today)

    if (usersError) {
      console.error('❌ Error fetching user approval status:', usersError)
      return { yesterday: 0, monthly: 0 }
    }

    console.log('✅ NFT approved users found:', usersData)
    console.log('✅ Operation start date check applied (must be <= today)')

    // NFT承認済みかつ運用開始済みユーザーIDを取得
    const eligibleUserIds = usersData.map(user => user.user_id)

    console.log('✅ Eligible users for profit calculation (operation started):', eligibleUserIds)

    if (eligibleUserIds.length === 0) {
      console.log('⚠️ No eligible users found')
      return { yesterday: 0, monthly: 0 }
    }

    console.log('📊 Fetching profit data for users:', eligibleUserIds)
    console.log('📊 Date range:', monthStart, 'to', monthEnd)
    
    const { data, error } = await supabase
      .from('user_daily_profit')
      .select('date, daily_profit, user_id')
      .in('user_id', eligibleUserIds)
      .gte('date', monthStart)
      .lte('date', monthEnd)

    if (error) {
      console.error('❌ Error fetching referral profits:', error)
      return { yesterday: 0, monthly: 0 }
    }

    console.log('✅ Raw profit data for eligible users:', data)
    console.log('📊 Data count:', data?.length || 0)

    let yesterday = 0
    let monthly = 0

    data.forEach(row => {
      const profit = parseFloat(row.daily_profit) || 0
      
      // 昨日の利益
      if (row.date === yesterdayStr) {
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
          Level1-3投資額: ${(totalLevel3Investment || 0).toLocaleString()}
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