"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Target, TrendingUp, Loader2, DollarSign, Users } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface TotalProfitCardProps {
  userId: string
  totalInvestment: number
  level1Investment: number
  level2Investment: number
  level3Investment: number
}

interface TotalProfitData {
  yesterdayTotal: number
  monthlyTotal: number
  breakdown: {
    personalYesterday: number
    referralYesterday: number
    personalMonthly: number
    referralMonthly: number
  }
}

export function TotalProfitCard({ 
  userId, 
  totalInvestment,
  level1Investment, 
  level2Investment, 
  level3Investment 
}: TotalProfitCardProps) {
  const [profitData, setProfitData] = useState<TotalProfitData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")

  useEffect(() => {
    if (userId) {
      fetchTotalProfit()
    }
  }, [userId, totalInvestment, level1Investment, level2Investment, level3Investment])

  const fetchTotalProfit = async () => {
    try {
      setLoading(true)
      setError("")

      // 昨日の日付を取得
      const yesterday = new Date()
      yesterday.setDate(yesterday.getDate() - 1)
      const yesterdayStr = yesterday.toISOString().split('T')[0]

      // 今月の開始日と終了日を取得
      const now = new Date()
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0]
      const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString().split('T')[0]

      // 昨日の総利益を取得
      const { data: yesterdayData, error: yesterdayError } = await supabase
        .from('user_daily_profit')
        .select('daily_profit')
        .eq('user_id', userId)
        .eq('date', yesterdayStr)
        .maybeSingle()

      if (yesterdayError && yesterdayError.code !== 'PGRST116' && yesterdayError.code !== '42P01') {
        console.log('Yesterday total profit error:', yesterdayError)
        throw yesterdayError
      }

      // 今月の総利益累計を取得
      const { data: monthlyData, error: monthlyError } = await supabase
        .from('user_daily_profit')
        .select('daily_profit')
        .eq('user_id', userId)
        .gte('date', monthStart)
        .lte('date', monthEnd)

      if (monthlyError && monthlyError.code !== 'PGRST116' && monthlyError.code !== '42P01') {
        console.log('Monthly total profit error:', monthlyError)
        throw monthlyError
      }

      // 個人利益（実際のデータ）
      const personalYesterday = yesterdayData ? yesterdayData.daily_profit : 0
      const personalMonthly = monthlyData ? 
        monthlyData.reduce((sum, record) => sum + record.daily_profit, 0) : 0

      // 紹介報酬は別途計算（ReferralProfitCardと同じロジック）
      const referralProfits = await calculateReferralProfits(userId, monthStart, monthEnd, yesterdayStr)
      const referralYesterday = referralProfits.yesterday
      const referralMonthly = referralProfits.monthly

      // 合計を計算
      const yesterdayTotal = personalYesterday + referralYesterday
      const monthlyTotal = personalMonthly + referralMonthly

      setProfitData({
        yesterdayTotal,
        monthlyTotal,
        breakdown: {
          personalYesterday,
          referralYesterday,
          personalMonthly,
          referralMonthly
        }
      })

    } catch (err: any) {
      console.error("Total profit fetch error:", err)
      setError("合計利益データの取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  // 紹介報酬計算関数（ReferralProfitCardと同じロジック）
  const calculateReferralProfits = async (userId: string, monthStart: string, monthEnd: string, yesterdayStr: string) => {
    try {
      // 紹介報酬率の定義
      const level1Rate = 0.20 // 20%
      const level2Rate = 0.10 // 10%
      const level3Rate = 0.05 // 5%

      // 各レベルの紹介者IDを取得
      const level1UserIds = await getDirectReferrals(userId)
      const level2UserIds = await getLevel2Referrals(userId)
      const level3UserIds = await getLevel3Referrals(userId)

      // 各レベルの利益を取得
      const level1Profits = await getReferralProfits(level1UserIds, monthStart, monthEnd, yesterdayStr)
      const level2Profits = await getReferralProfits(level2UserIds, monthStart, monthEnd, yesterdayStr)
      const level3Profits = await getReferralProfits(level3UserIds, monthStart, monthEnd, yesterdayStr)

      // 紹介報酬計算
      const level1Yesterday = level1Profits.yesterday * level1Rate
      const level1Monthly = level1Profits.monthly * level1Rate
      
      const level2Yesterday = level2Profits.yesterday * level2Rate
      const level2Monthly = level2Profits.monthly * level2Rate
      
      const level3Yesterday = level3Profits.yesterday * level3Rate
      const level3Monthly = level3Profits.monthly * level3Rate

      return {
        yesterday: level1Yesterday + level2Yesterday + level3Yesterday,
        monthly: level1Monthly + level2Monthly + level3Monthly
      }
    } catch (error) {
      console.error('Referral profit calculation error:', error)
      return { yesterday: 0, monthly: 0 }
    }
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

  // 指定されたユーザーIDリストの利益を取得
  const getReferralProfits = async (userIds: string[], monthStart: string, monthEnd: string, yesterdayStr: string) => {
    if (userIds.length === 0) {
      return { yesterday: 0, monthly: 0 }
    }

    // NFT承認済みかつ運用開始済みユーザーのみフィルター
    const today = new Date().toISOString().split('T')[0]

    const { data: usersData, error: usersError } = await supabase
      .from('users')
      .select('user_id, has_approved_nft, operation_start_date')
      .in('user_id', userIds)
      .eq('has_approved_nft', true)
      .not('operation_start_date', 'is', null)
      .lte('operation_start_date', today)

    if (usersError) {
      console.error('Error fetching user approval status:', usersError)
      return { yesterday: 0, monthly: 0 }
    }

    const eligibleUserIds = usersData.map(user => user.user_id)

    if (eligibleUserIds.length === 0) {
      return { yesterday: 0, monthly: 0 }
    }

    const { data, error } = await supabase
      .from('user_daily_profit')
      .select('date, daily_profit, user_id')
      .in('user_id', eligibleUserIds)
      .gte('date', monthStart)
      .lte('date', monthEnd)

    if (error) {
      console.error('Error fetching referral profits:', error)
      return { yesterday: 0, monthly: 0 }
    }

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

  if (loading) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardHeader className="pb-3">
          <CardTitle className="text-gray-300 text-sm font-medium">合計利益</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-center space-x-2">
            <Loader2 className="h-5 w-5 text-yellow-400 animate-spin" />
            <span className="text-sm text-gray-400">読み込み中...</span>
          </div>
        </CardContent>
      </Card>
    )
  }

  const totalReferralInvestment = level1Investment + level2Investment + level3Investment

  return (
    <Card className="bg-gray-800 border-gray-700 border-yellow-500/20">
      <CardHeader className="pb-3">
        <CardTitle className="text-gray-300 text-sm font-medium flex items-center gap-2">
          <Target className="h-4 w-4 text-yellow-400" />
          合計利益
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="text-xs text-gray-400 mb-3 space-y-1">
          <div>個人投資: ${(totalInvestment || 0).toLocaleString()}</div>
          <div>紹介投資: ${(totalReferralInvestment || 0).toLocaleString()}</div>
        </div>
        
        {/* 昨日の合計利益 */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-xs text-gray-400">昨日の合計</span>
            <div className="flex items-center space-x-1">
              <TrendingUp className="h-3 w-3 text-yellow-400" />
              <span className={`text-sm font-semibold ${
                (profitData?.yesterdayTotal || 0) >= 0 ? "text-yellow-400" : "text-red-400"
              }`}>
                ${(profitData?.yesterdayTotal || 0).toFixed(3)}
              </span>
            </div>
          </div>
          
          {/* 内訳（昨日） */}
          {profitData && (
            <div className="text-xs space-y-1 ml-4 opacity-75">
              <div className="flex justify-between">
                <span className="text-green-400 flex items-center gap-1">
                  <DollarSign className="h-3 w-3" />個人:
                </span>
                <span className="text-green-400">${profitData.breakdown.personalYesterday.toFixed(3)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-purple-400 flex items-center gap-1">
                  <Users className="h-3 w-3" />紹介:
                </span>
                <span className="text-purple-400">${profitData.breakdown.referralYesterday.toFixed(3)}</span>
              </div>
            </div>
          )}
        </div>

        {/* 今月の累計合計利益 */}
        <div className="space-y-2 border-t border-gray-600 pt-3">
          <div className="flex items-center justify-between">
            <span className="text-xs text-gray-400">今月累計</span>
            <div className="flex items-center space-x-1">
              <TrendingUp className="h-3 w-3 text-amber-400" />
              <span className={`text-lg font-bold ${
                (profitData?.monthlyTotal || 0) >= 0 ? "text-amber-400" : "text-red-400"
              }`}>
                ${(profitData?.monthlyTotal || 0).toFixed(3)}
              </span>
            </div>
          </div>

          {/* 内訳（今月） */}
          {profitData && (
            <div className="text-xs space-y-1 ml-4 opacity-75">
              <div className="flex justify-between">
                <span className="text-green-400 flex items-center gap-1">
                  <DollarSign className="h-3 w-3" />個人:
                </span>
                <span className="text-green-400">${profitData.breakdown.personalMonthly.toFixed(3)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-purple-400 flex items-center gap-1">
                  <Users className="h-3 w-3" />紹介:
                </span>
                <span className="text-purple-400">${profitData.breakdown.referralMonthly.toFixed(3)}</span>
              </div>
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