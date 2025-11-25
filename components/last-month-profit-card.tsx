"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Calendar, Loader2 } from "lucide-react"
import { supabase } from "@/lib/supabase"

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

  useEffect(() => {
    if (userId) {
      fetchLastMonthProfit()
    }
  }, [userId])

  const fetchLastMonthProfit = async () => {
    try {
      setLoading(true)
      setError("")

      // 先月の開始日と終了日を取得
      const now = new Date()
      const lastMonthDate = new Date(now.getFullYear(), now.getMonth() - 1, 1)
      const year = lastMonthDate.getFullYear()
      const month = lastMonthDate.getMonth() + 1
      const monthStart = new Date(year, lastMonthDate.getMonth(), 1).toISOString().split('T')[0]
      const monthEnd = new Date(year, lastMonthDate.getMonth() + 1, 0).toISOString().split('T')[0]

      // 月の表示用（例: 2025年10月）
      setLastMonth(`${year}年${month}月`)

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

      // 紹介報酬（user_referral_profit）
      const { data: referralProfitData, error: referralError } = await supabase
        .from('user_referral_profit')
        .select('profit_amount')
        .eq('user_id', userId)
        .gte('date', monthStart)
        .lte('date', monthEnd)

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
        </div>

        {error && (
          <p className="text-xs text-red-400 mt-2">{error}</p>
        )}
      </CardContent>
    </Card>
  )
}
