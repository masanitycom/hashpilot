"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Calendar, TrendingDown, TrendingUp, Loader2 } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface MonthlyProfitCardProps {
  userId: string
}

export function MonthlyProfitCard({ userId }: MonthlyProfitCardProps) {
  const [profit, setProfit] = useState<number>(0)
  const [averageYieldRate, setAverageYieldRate] = useState<number>(0)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string>("")
  const [currentMonth, setCurrentMonth] = useState("")

  useEffect(() => {
    if (userId) {
      fetchMonthlyProfit()
    }
  }, [userId])

  // 紹介報酬を計算する関数
  const calculateReferralProfit = async (userId: string, monthStart: string, monthEnd: string): Promise<number> => {
    try {
      // 紹介報酬率の定義
      const level1Rate = 0.20 // 20%
      const level2Rate = 0.10 // 10%
      const level3Rate = 0.05 // 5%

      // 各レベルの紹介者IDを取得
      const level1UserIds = await getDirectReferrals(userId)
      const level2UserIds = await getLevel2Referrals(userId)
      const level3UserIds = await getLevel3Referrals(userId)

      // 各レベルの紹介者の利益を取得
      const level1Profits = await getReferralProfits(level1UserIds, monthStart, monthEnd)
      const level2Profits = await getReferralProfits(level2UserIds, monthStart, monthEnd)
      const level3Profits = await getReferralProfits(level3UserIds, monthStart, monthEnd)

      // 紹介報酬計算
      const level1Reward = level1Profits * level1Rate
      const level2Reward = level2Profits * level2Rate
      const level3Reward = level3Profits * level3Rate

      return level1Reward + level2Reward + level3Reward
    } catch (error) {
      console.error('紹介報酬計算エラー:', error)
      return 0
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
  const getReferralProfits = async (userIds: string[], monthStart: string, monthEnd: string): Promise<number> => {
    if (userIds.length === 0) return 0

    // NFT承認済みかつ実際に運用開始しているユーザーのみフィルター
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
      console.error('Error fetching user approval status:', usersError)
      return 0
    }

    const eligibleUserIds = usersData.map(user => user.user_id)
    if (eligibleUserIds.length === 0) return 0

    const { data, error } = await supabase
      .from('user_daily_profit')
      .select('daily_profit')
      .in('user_id', eligibleUserIds)
      .gte('date', monthStart)
      .lte('date', monthEnd)

    if (error) {
      console.error('Error fetching referral profits:', error)
      return 0
    }

    return data.reduce((sum, row) => sum + (parseFloat(row.daily_profit) || 0), 0)
  }

  const fetchMonthlyProfit = async () => {
    try {
      setLoading(true)
      setError("")

      if (!userId) {
        setError("ユーザーIDが見つかりません")
        return
      }

      // 今月の開始日と終了日を取得（UTC）
      const now = new Date()
      const year = now.getFullYear()
      const month = now.getMonth()
      const monthStart = new Date(Date.UTC(year, month, 1)).toISOString().split('T')[0]
      const monthEnd = new Date(Date.UTC(year, month + 1, 0)).toISOString().split('T')[0]
      
      // 月名を設定
      setCurrentMonth(`${year}年${month + 1}月`)


      // 個人の今月の累積利益を取得
      const { data: profitData, error: profitError } = await supabase
        .from('user_daily_profit')
        .select('daily_profit, base_amount, user_rate')
        .eq('user_id', userId)
        .gte('date', monthStart)
        .lte('date', monthEnd)

      if (profitError) {
        console.log('user_daily_profit access error:', profitError)
        // テーブルが存在しない場合は利益0として続行
        if (profitError.code === '42P01' || profitError.code === 'PGRST116') {
          // テーブル不存在またはデータなしの場合
        } else {
          throw profitError
        }
      }

      // 紹介報酬を計算するための紹介者データを取得
      const referralProfit = await calculateReferralProfit(userId, monthStart, monthEnd)

      // 個人利益+紹介報酬と平均受取率を計算
      let personalProfit = 0
      let totalYieldRate = 0
      let validDays = 0

      if (profitData && profitData.length > 0) {
        profitData.forEach(record => {
          const dailyValue = parseFloat(record.daily_profit) || 0
          const userRate = parseFloat(record.user_rate) || 0
          const baseAmount = parseFloat(record.base_amount) || 0
          personalProfit += dailyValue
          
          if (userRate > 0) {
            totalYieldRate += userRate
            validDays++
          }
        })
      }

      // 平均受取率を計算
      const avgYieldRate = validDays > 0 ? totalYieldRate / validDays : 0
      setAverageYieldRate(avgYieldRate)

      // 合計利益を計算（個人+紹介報酬）
      const totalProfit = personalProfit + referralProfit

      setProfit(totalProfit)
    } catch (err: any) {
      console.error("今月の利益取得エラー:", err)
      setError("データの取得に失敗しました")
      setProfit(0)
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardHeader className="pb-3">
          <CardTitle className="text-gray-300 text-sm font-medium">今月の累積利益</CardTitle>
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

  return (
    <Card className="bg-gray-800 border-gray-700">
      <CardHeader className="pb-3">
        <CardTitle className="text-gray-300 text-sm font-medium">今月の累積利益</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="flex items-center space-x-2">
          {profit >= 0 ? (
            <TrendingUp className="h-5 w-5 text-purple-400" />
          ) : (
            <TrendingDown className="h-5 w-5 text-red-400" />
          )}
          <div className="flex flex-col">
            <span className={`text-2xl font-bold ${profit >= 0 ? "text-purple-400" : "text-red-400"}`}>
              ${profit >= 0 ? "+" : ""}
              {profit.toFixed(3)}
            </span>
            {averageYieldRate !== 0 && (
              <span className="text-sm text-gray-400">
                平均日利: {(averageYieldRate * 100).toFixed(3)}%
              </span>
            )}
          </div>
        </div>
        <p className="text-xs text-gray-500 mt-1">
          {error ? error : `${currentMonth}の累積利益`}
        </p>
      </CardContent>
    </Card>
  )
}

