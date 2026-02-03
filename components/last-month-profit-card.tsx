"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Calendar, Loader2, History } from "lucide-react"
import { supabase } from "@/lib/supabase"
import Link from "next/link"

interface LastMonthProfitCardProps {
  userId: string
}

export function LastMonthProfitCard({ userId }: LastMonthProfitCardProps) {
  const [personalProfit, setPersonalProfit] = useState<number>(0)
  const [referralProfit, setReferralProfit] = useState<number>(0)
  const [totalProfit, setTotalProfit] = useState<number>(0)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")
  const [lastMonth, setLastMonth] = useState("")
  const [isCalculating, setIsCalculating] = useState(false) // 集計中フラグ

  useEffect(() => {
    if (userId) {
      fetchLastMonthProfit()
    }
  }, [userId])

  const fetchLastMonthProfit = async () => {
    try {
      setLoading(true)
      setError("")

      // 先月の開始日と終了日を取得（日本時間基準）
      const now = new Date()
      const jstOffset = 9 * 60 // 日本時間は UTC+9
      const jstNow = new Date(now.getTime() + jstOffset * 60 * 1000)

      const currentYear = jstNow.getUTCFullYear()
      const currentMonth = jstNow.getUTCMonth() + 1 // 1-indexed (1 = 1月, 12 = 12月)

      // 先月の年月を計算（年跨ぎ対応）
      const lastMonthNum = currentMonth === 1 ? 12 : currentMonth - 1
      const lastMonthYear = currentMonth === 1 ? currentYear - 1 : currentYear

      // 月初（1日）- JavaScriptのDate.UTCは0-indexedなので-1する
      const monthStartDate = new Date(Date.UTC(lastMonthYear, lastMonthNum - 1, 1))
      const monthStart = monthStartDate.toISOString().split('T')[0]

      // 月末（翌月の0日 = 当月の最終日）
      const monthEndDate = new Date(Date.UTC(lastMonthYear, lastMonthNum, 0))
      const monthEnd = monthEndDate.toISOString().split('T')[0]

      console.log('[LastMonthProfit] 日付計算:', {
        now: now.toISOString(),
        jstNow: jstNow.toISOString(),
        currentYear,
        currentMonth,
        lastMonthNum,
        lastMonthYear,
        monthStart,
        monthEnd
      })

      // 月の表示用（例: 2025年12月）
      setLastMonth(`${lastMonthYear}年${lastMonthNum}月`)

      // 月初（1日～3日）の場合、前月の最終日の日利が設定されているか確認
      const today = jstNow.getUTCDate()
      if (today <= 3) {
        // 前月の最終日の日利が設定されているか確認（全ユーザーで1件でもあればOK）
        console.log('[LastMonthProfit] チェック対象日付:', monthEnd)
        const { data: lastDayProfit, error: checkError } = await supabase
          .from('user_daily_profit')
          .select('date')
          .eq('date', monthEnd)
          .limit(1)

        console.log('[LastMonthProfit] クエリ結果:', { lastDayProfit, checkError })

        if (checkError && checkError.code !== 'PGRST116') {
          throw checkError
        }

        // 前月の最終日の日利が未設定の場合は「集計中」表示
        if (!lastDayProfit || lastDayProfit.length === 0) {
          console.log('[LastMonthProfit] 前月最終日のデータなし - 集計中表示')
          setIsCalculating(true)
          setLoading(false)
          return // データ取得をスキップして集計中表示
        }
        console.log('[LastMonthProfit] 前月最終日のデータあり - カード表示')
      }

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

      // 紹介報酬（monthly_referral_profit）
      const yearMonth = `${lastMonthYear}-${String(lastMonthNum).padStart(2, '0')}`
      const { data: referralProfitData, error: referralError } = await supabase
        .from('monthly_referral_profit')
        .select('profit_amount')
        .eq('user_id', userId)
        .eq('year_month', yearMonth)

      if (referralError && referralError.code !== 'PGRST116') {
        throw referralError
      }

      // 個人利益の合計
      const personalTotal = dailyProfitData
        ? dailyProfitData.reduce((sum, record) => sum + record.daily_profit, 0)
        : 0

      // 紹介報酬の合計
      const referralTotal = referralProfitData
        ? referralProfitData.reduce((sum, record) => sum + parseFloat(record.profit_amount), 0)
        : 0

      // 合計
      const total = personalTotal + referralTotal
      setPersonalProfit(personalTotal)
      setReferralProfit(referralTotal)
      setTotalProfit(total)

    } catch (err: any) {
      console.error("Last month profit fetch error:", err)
      setError("データの取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardHeader className="pb-3">
          <CardTitle className="text-gray-300 text-sm font-medium">前月の確定利益</CardTitle>
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

  // 集計中の場合
  if (isCalculating) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardHeader className="pb-3">
          <CardTitle className="text-gray-300 text-sm font-medium flex items-center gap-2">
            <Calendar className="h-4 w-4 text-yellow-400" />
            前月の確定利益
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-center">
            <div className="text-3xl font-bold text-yellow-400">
              集計中...
            </div>
            <div className="text-xs text-gray-400 mt-2">
              {lastMonth}の利益を集計しています
            </div>
            <div className="mt-3 pt-3 border-t border-gray-700">
              <p className="text-xs text-gray-400">
                月末の日利設定後に確定利益が表示されます
              </p>
            </div>
          </div>
        </CardContent>
      </Card>
    )
  }

  // 前月の利益データが存在しない場合は非表示
  if (totalProfit === 0 && personalProfit === 0 && referralProfit === 0) {
    return null
  }

  return (
    <Card className="bg-gray-800 border-gray-700">
      <CardHeader className="pb-3">
        <CardTitle className="text-gray-300 text-sm font-medium flex items-center gap-2">
          <Calendar className="h-4 w-4 text-green-400" />
          前月の確定利益
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="text-center">
          <div className={`text-3xl font-bold ${
            totalProfit >= 0 ? "text-green-400" : "text-red-400"
          }`}>
            ${totalProfit.toFixed(3)}
          </div>
          <div className="text-xs text-gray-400 mt-2">
            {lastMonth}の確定利益
          </div>

          {/* 内訳表示 */}
          <div className="mt-3 pt-3 border-t border-gray-700 space-y-1">
            <div className="flex justify-between text-xs">
              <span className="text-gray-400">個人利益:</span>
              <span className={personalProfit >= 0 ? "text-green-400" : "text-red-400"}>
                ${personalProfit.toFixed(3)}
              </span>
            </div>
            <div className="flex justify-between text-xs">
              <span className="text-gray-400">紹介報酬:</span>
              <span className={referralProfit >= 0 ? "text-green-400" : "text-red-400"}>
                ${referralProfit.toFixed(3)}
              </span>
            </div>
          </div>

          {/* 月別履歴リンク */}
          <div className="mt-4">
            <Link href="/profit-history">
              <Button variant="outline" size="sm" className="w-full bg-gray-700 text-white border-gray-600 hover:bg-gray-600">
                <History className="h-3 w-3 mr-2" />
                月別履歴を見る
              </Button>
            </Link>
          </div>
        </div>

        {error && (
          <p className="text-xs text-red-400 mt-2">{error}</p>
        )}
      </CardContent>
    </Card>
  )
}
