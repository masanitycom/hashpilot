"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Calendar, Loader2 } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface MonthlyCumulativeProfitCardProps {
  userId: string
}

export function MonthlyCumulativeProfitCard({ userId }: MonthlyCumulativeProfitCardProps) {
  const [monthlyProfit, setMonthlyProfit] = useState<number>(0)
  const [personalProfit, setPersonalProfit] = useState<number>(0)
  const [referralProfit, setReferralProfit] = useState<number>(0)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")
  const [currentMonth, setCurrentMonth] = useState("")

  useEffect(() => {
    if (userId) {
      fetchMonthlyProfit()
    }
  }, [userId])

  const fetchMonthlyProfit = async () => {
    try {
      setLoading(true)
      setError("")

      // 今月の開始日と終了日を取得（日本時間基準）
      const now = new Date()
      const jstOffset = 9 * 60 // 日本時間は UTC+9
      const jstNow = new Date(now.getTime() + jstOffset * 60 * 1000)

      let year = jstNow.getUTCFullYear()
      let currentMonth = jstNow.getUTCMonth() // 0-indexed (11 = 12月)
      let month = currentMonth + 1 // 12（表示用）

      // 月初（1日）
      let monthStartDate = new Date(Date.UTC(year, currentMonth, 1))
      let monthStart = monthStartDate.toISOString().split('T')[0]

      // 月末（翌月の0日 = 当月の最終日）
      let monthEndDate = new Date(Date.UTC(year, currentMonth + 1, 0))
      let monthEnd = monthEndDate.toISOString().split('T')[0]

      console.log('[MonthlyCumulative] 初期日付計算:', {
        now: now.toISOString(),
        jstNow: jstNow.toISOString(),
        year,
        currentMonth,
        month,
        monthStart,
        monthEnd
      })

      // 月初（1日～3日）の場合、前月の最終日の日利が設定されているか確認
      const today = jstNow.getUTCDate()
      if (today <= 3) {
        // 前月の最終日を計算（日本時間基準、年跨ぎ対応）
        const lastMonthIdx = currentMonth === 0 ? 11 : currentMonth - 1 // 0-indexed
        const lastMonthYear = currentMonth === 0 ? year - 1 : year
        const lastMonthEndDate = new Date(Date.UTC(lastMonthYear, lastMonthIdx + 1, 0))
        const lastMonthEnd = lastMonthEndDate.toISOString().split('T')[0]

        console.log('[MonthlyCumulative] 前月最終日計算:', {
          lastMonthIdx,
          lastMonthYear,
          lastMonthEnd
        })

        // 前月の最終日の日利が設定されているか確認（全ユーザーで1件でもあればOK）
        console.log('[MonthlyCumulative] チェック対象日付:', lastMonthEnd)
        const { data: lastDayProfit, error: checkError } = await supabase
          .from('user_daily_profit')
          .select('date')
          .eq('date', lastMonthEnd)
          .limit(1)

        console.log('[MonthlyCumulative] クエリ結果:', { lastDayProfit, checkError })

        if (checkError && checkError.code !== 'PGRST116') {
          throw checkError
        }

        // 前月の最終日の日利が未設定の場合は、前月のデータを表示
        if (!lastDayProfit || lastDayProfit.length === 0) {
          console.log('[MonthlyCumulative] 前月最終日のデータなし - 前月データを表示')
          year = lastMonthYear  // 年跨ぎ対応
          month = lastMonthIdx + 1 // 表示用（1-indexed）
          monthStartDate = new Date(Date.UTC(lastMonthYear, lastMonthIdx, 1))
          monthStart = monthStartDate.toISOString().split('T')[0]
          monthEnd = lastMonthEnd
        } else {
          console.log('[MonthlyCumulative] 前月最終日のデータあり - 今月データを表示')
        }
      }

      // 月の表示用（例: 2025年11月）
      setCurrentMonth(`${year}年${month}月`)

      // 個人利益（user_daily_profit）
      const { data: dailyProfitData, error: dailyError } = await supabase
        .from('user_daily_profit')
        .select('daily_profit')
        .eq('user_id', userId)
        .gte('date', monthStart)
        .lte('date', monthEnd)

      if (dailyError && dailyError.code !== 'PGRST116') {
        throw dailyError
      }

      // 個人利益の合計
      const personalTotal = dailyProfitData
        ? dailyProfitData.reduce((sum, record) => sum + record.daily_profit, 0)
        : 0

      // 紹介報酬は月末集計のため、当月は$0で表示
      // 注: 紹介報酬は月末にprocess_monthly_referral_rewardで計算され
      //     user_referral_profit_monthlyテーブルに保存される
      const total = personalTotal
      setPersonalProfit(personalTotal)
      setReferralProfit(0)  // 紹介報酬は月末集計後に確定
      setMonthlyProfit(total)

    } catch (err: any) {
      console.error("Monthly cumulative profit fetch error:", err)
      setError("データの取得に失敗しました")
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
            <Loader2 className="h-5 w-5 text-blue-400 animate-spin" />
            <span className="text-sm text-gray-400">読み込み中...</span>
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card className="bg-gray-800 border-gray-700">
      <CardHeader className="pb-3">
        <CardTitle className="text-gray-300 text-sm font-medium flex items-center gap-2">
          <Calendar className="h-4 w-4 text-blue-400" />
          今月の累積利益
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="text-center">
          <div className={`text-3xl font-bold ${
            monthlyProfit >= 0 ? "text-blue-400" : "text-red-400"
          }`}>
            ${monthlyProfit.toFixed(3)}
          </div>
          <div className="text-xs text-gray-400 mt-2">
            {currentMonth}の累積利益
          </div>

          {/* 内訳表示 */}
          <div className="mt-3 pt-3 border-t border-gray-700 space-y-1">
            <div className="flex justify-between text-xs">
              <span className="text-gray-400">個人利益:</span>
              <span className={personalProfit >= 0 ? "text-green-400" : "text-red-400"}>
                ${personalProfit.toFixed(3)}
              </span>
            </div>
          </div>
        </div>

        {error && (
          <p className="text-xs text-red-400 mt-2">{error}</p>
        )}
      </CardContent>
    </Card>
  )
}
