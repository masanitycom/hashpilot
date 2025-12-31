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

  // 注: 紹介報酬は月末集計のため、当月中は$0で表示
  // 月末にprocess_monthly_referral_rewardで計算され、user_referral_profit_monthlyテーブルに保存される

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

      // 紹介報酬は月末集計のため当月は$0（個人利益のみ表示）
      const referralProfit = 0

      // 個人利益と平均受取率を計算
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

