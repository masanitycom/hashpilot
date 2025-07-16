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
        return
      }

      // 昨日の日付を取得（UTCで処理）
      const now = new Date()
      const yesterday = new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate() - 1))
      const yesterdayStr = yesterday.toISOString().split('T')[0]
      
      // デバッグ用: 固定日付でテスト
      // const yesterdayStr = '2025-07-09'


      // user_daily_profitテーブルから昨日の確定利益のみ取得
      const { data: profitData, error: profitError } = await supabase
        .from('user_daily_profit')
        .select('daily_profit, base_amount')
        .eq('user_id', userId)
        .eq('date', yesterdayStr)
        .single()

      if (profitError) {
        // データが見つからない場合は0として扱う
        if (profitError.code === 'PGRST116') {
          setProfit(0)
          setYieldRate(0)
        } else {
          throw profitError
        }
      } else {
        const profitValue = parseFloat(profitData?.daily_profit) || 0
        const baseAmount = parseFloat(profitData?.base_amount) || 0
        // 受取率を計算で求める（APIで露出させない）
        const calculatedRate = baseAmount > 0 ? profitValue / baseAmount : 0
        setProfit(profitValue)
        setYieldRate(calculatedRate)
      }
    } catch (err: any) {
      console.error("昨日の利益取得エラー:", err)
      setError("データの取得に失敗しました")
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
        <CardTitle className="text-gray-300 text-sm font-medium">昨日の確定利益</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="flex items-center space-x-2">
          {profit >= 0 ? (
            <TrendingUp className="h-5 w-5 text-green-400" />
          ) : (
            <TrendingDown className="h-5 w-5 text-red-400" />
          )}
          <div className="flex flex-col">
            <span className={`text-2xl font-bold ${profit >= 0 ? "text-green-400" : "text-red-400"}`}>
              ${profit >= 0 ? "+" : ""}
              {profit.toFixed(3)}
            </span>
            {yieldRate !== 0 && (
              <span className="text-sm text-gray-400">
                日利: {(yieldRate * 100).toFixed(3)}%
              </span>
            )}
          </div>
        </div>
        <p className="text-xs text-gray-500 mt-1">
          {error ? error : "前日の確定済み利益"}
        </p>
      </CardContent>
    </Card>
  )
}

