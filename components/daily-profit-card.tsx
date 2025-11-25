"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { DollarSign, TrendingDown, TrendingUp, Loader2 } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface DailyProfitCardProps {
  userId: string
}

export function DailyProfitCard({ userId }: DailyProfitCardProps) {
  const [profit, setProfit] = useState<number>(0)
  const [yieldRate, setYieldRate] = useState<number>(0)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string>("")

  useEffect(() => {
    if (userId) {
      fetchYesterdayProfit()
    }
  }, [userId])

  const fetchYesterdayProfit = async () => {
    try {
      setLoading(true)
      setError("")

      if (!userId) {
        setError("ユーザーIDが見つかりません")
        setProfit(0)
        setYieldRate(0)
        return
      }

      // 昨日の日付を取得
      const yesterday = new Date()
      yesterday.setDate(yesterday.getDate() - 1)
      const yesterdayStr = yesterday.toISOString().split('T')[0]

      // 昨日のデータのみ取得（最新ではなく昨日）
      const { data: profitData, error: profitError } = await supabase
        .from('user_daily_profit')
        .select('daily_profit, base_amount, user_rate')
        .eq('user_id', userId)
        .eq('date', yesterdayStr)
        .maybeSingle()

      if (profitError) {
        console.log('user_daily_profit table access error:', profitError)
        // テーブルが存在しないか、アクセスできない場合はデフォルト値を設定
        setProfit(0)
        setYieldRate(0)
        setError("利益データ未設定")
      } else if (profitData) {
        const profitValue = parseFloat(profitData.daily_profit) || 0
        const userRate = parseFloat(profitData.user_rate) || 0
        
        setProfit(profitValue)
        setYieldRate(userRate * 100) // ユーザー利率をパーセント表示
      } else {
        // データが存在しない場合
        setProfit(0)
        setYieldRate(0)
        setError("利益データ未生成")
      }
    } catch (err: any) {
      console.error("昨日の利益取得エラー:", err)
      setError("利益データ読み込み中")
      setProfit(0)
      setYieldRate(0)
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardHeader className="pb-3">
          <CardTitle className="text-gray-300 text-sm font-medium">昨日の確定利益</CardTitle>
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
        <CardTitle className="text-gray-300 text-sm font-medium">昨日の確定日利</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="flex items-center space-x-2">
          {profit >= 0 ? (
            <TrendingUp className="h-5 w-5 text-green-400" />
          ) : (
            <TrendingDown className="h-5 w-5 text-red-400" />
          )}
          <div className="flex flex-col">
            {yieldRate !== 0 && (
              <span className={`text-2xl font-bold ${yieldRate >= 0 ? "text-green-400" : "text-red-400"}`}>
                {yieldRate >= 0 ? "+" : ""}{yieldRate.toFixed(3)}%
              </span>
            )}
            <span className={`text-sm ${profit >= 0 ? "text-green-300" : "text-red-300"}`}>
              確定利益: ${profit >= 0 ? "+" : ""}{profit.toFixed(3)}
            </span>
          </div>
        </div>
        <p className="text-xs text-gray-500 mt-1">
          {error ? error : "前日のユーザー受取率"}
        </p>
      </CardContent>
    </Card>
  )
}

