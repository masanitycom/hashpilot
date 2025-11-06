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

  // user_referral_profitテーブルから実際の紹介報酬を取得
  const calculateReferralProfits = async (userId: string, monthStart: string, monthEnd: string, yesterdayStr: string) => {
    try {
      const { data, error } = await supabase
        .from('user_referral_profit')
        .select('date, profit_amount')
        .eq('user_id', userId)
        .gte('date', monthStart)
        .lte('date', monthEnd)

      if (error) {
        console.error('紹介報酬取得エラー:', error)
        return { yesterday: 0, monthly: 0 }
      }

      if (!data || data.length === 0) {
        return { yesterday: 0, monthly: 0 }
      }

      let yesterday = 0
      let monthly = 0

      data.forEach(row => {
        const profit = parseFloat(row.profit_amount) || 0

        if (row.date === yesterdayStr) {
          yesterday += profit
        }

        monthly += profit
      })

      return { yesterday, monthly }
    } catch (error) {
      console.error('Referral profit calculation error:', error)
      return { yesterday: 0, monthly: 0 }
    }
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
      <CardContent className="space-y-3">
        {/* 昨日の合計利益 */}
        <div className="text-center">
          <div className="text-xs text-gray-400 mb-2">昨日の利益</div>
          <div className={`text-2xl font-bold mb-3 ${
            (profitData?.yesterdayTotal || 0) >= 0 ? "text-amber-400" : "text-red-400"
          }`}>
            ${(profitData?.yesterdayTotal || 0).toFixed(3)}
          </div>

          {/* 内訳 */}
          {profitData && (
            <div className="text-xs space-y-1">
              <div className="flex justify-between">
                <span className="text-green-400">個人:</span>
                <span className="text-green-400">${profitData.breakdown.personalYesterday.toFixed(3)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-purple-400">紹介:</span>
                <span className="text-purple-400">${profitData.breakdown.referralYesterday.toFixed(3)}</span>
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