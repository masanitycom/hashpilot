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
        return
      }

      // 昨日の日付を取得
      const yesterday = new Date()
      yesterday.setDate(yesterday.getDate() - 1)
      const yesterdayStr = yesterday.toISOString().split('T')[0]

      console.log('DailyProfitCard Debug:', {
        userId,
        yesterdayStr,
        searchingFor: `user_id: ${userId}, date: ${yesterdayStr}`
      })

      // user_daily_profitテーブルから昨日の確定利益を取得
      const { data: profitData, error: profitError } = await supabase
        .from('user_daily_profit')
        .select('daily_profit')
        .eq('user_id', userId)
        .eq('date', yesterdayStr)
        .single()

      if (profitError) {
        // データが見つからない場合は0として扱う
        if (profitError.code === 'PGRST116') {
          setProfit(0)
        } else {
          throw profitError
        }
      } else {
        setProfit(profitData?.daily_profit || 0)
      }
    } catch (err: any) {
      console.error("昨日の利益取得エラー:", err)
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
        <CardTitle className="text-gray-300 text-sm font-medium">昨日の確定利益</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="flex items-center space-x-2">
          {profit >= 0 ? (
            <TrendingUp className="h-5 w-5 text-green-400" />
          ) : (
            <TrendingDown className="h-5 w-5 text-red-400" />
          )}
          <span className={`text-2xl font-bold ${profit >= 0 ? "text-green-400" : "text-red-400"}`}>
            ${profit >= 0 ? "+" : ""}
            {profit.toFixed(3)}
          </span>
        </div>
        <p className="text-xs text-gray-500 mt-1">
          {error ? error : "前日の確定済み利益"}
        </p>
      </CardContent>
    </Card>
  )
}

export default DailyProfitCard