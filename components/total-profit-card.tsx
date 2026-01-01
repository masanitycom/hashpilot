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

      // 日本時間で現在日時を取得
      const now = new Date()
      const jstOffset = 9 * 60 // 日本時間は UTC+9
      const jstNow = new Date(now.getTime() + jstOffset * 60 * 1000)

      // 昨日の日付を取得（日本時間基準）
      const jstYesterday = new Date(jstNow)
      jstYesterday.setUTCDate(jstYesterday.getUTCDate() - 1)
      const yesterdayStr = jstYesterday.toISOString().split('T')[0]

      // 今月の開始日と終了日を取得（日本時間基準）
      const currentYear = jstNow.getUTCFullYear()
      const currentMonth = jstNow.getUTCMonth() // 0-indexed
      const monthStart = new Date(Date.UTC(currentYear, currentMonth, 1)).toISOString().split('T')[0]
      const monthEnd = new Date(Date.UTC(currentYear, currentMonth + 1, 0)).toISOString().split('T')[0]

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

      // 紹介報酬は月末集計のため$0
      const referralYesterday = 0
      const referralMonthly = 0

      // 合計を計算（個人利益のみ）
      const yesterdayTotal = personalYesterday
      const monthlyTotal = personalMonthly

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

  // 注: 紹介報酬は月末集計のため、当月中は$0で表示
  // 月末にprocess_monthly_referral_rewardで計算され、user_referral_profit_monthlyテーブルに保存される
  // 前月の確定紹介報酬はlast-month-profit-card.tsxで表示される

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