"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { DollarSign, TrendingDown, TrendingUp, Loader2 } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface LatestProfitCardProps {
  userId: string
}

export function LatestProfitCard({ userId }: LatestProfitCardProps) {
  const [profit, setProfit] = useState<number>(0)
  const [profitDate, setProfitDate] = useState<string>("")
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string>("")

  useEffect(() => {
    if (userId) {
      fetchLatestProfit()
    }
  }, [userId])

  const fetchLatestProfit = async () => {
    try {
      setLoading(true)
      setError("")

      if (!userId) {
        setError("ユーザーIDが見つかりません")
        return
      }

      // 最新の確定利益を取得（最大30日前まで）
      const thirtyDaysAgo = new Date()
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)
      
      const { data: profitData, error: profitError } = await supabase
        .from('user_daily_profit')
        .select('date, daily_profit')
        .eq('user_id', userId)
        .gte('date', thirtyDaysAgo.toISOString().split('T')[0])
        .order('date', { ascending: false })
        .limit(1)
        .single()

      console.log('Latest profit query result:', {
        data: profitData,
        error: profitError
      })

      if (profitError) {
        if (profitError.code === 'PGRST116') {
          console.log('No profit data found')
          setProfit(0)
          setProfitDate("データなし")
        } else {
          throw profitError
        }
      } else {
        const profitValue = parseFloat(profitData?.daily_profit) || 0
        setProfit(profitValue)
        
        // 日付をフォーマット
        const date = new Date(profitData.date)
        const today = new Date()
        const yesterday = new Date(today)
        yesterday.setDate(yesterday.getDate() - 1)
        
        if (date.toDateString() === yesterday.toDateString()) {
          setProfitDate("昨日")
        } else if (date.toDateString() === today.toDateString()) {
          setProfitDate("本日")
        } else {
          setProfitDate(date.toLocaleDateString('ja-JP'))
        }
      }
    } catch (err: any) {
      console.error("最新利益取得エラー:", err)
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
          <CardTitle className="text-gray-300 text-sm font-medium">昨日の確定運用報酬</CardTitle>
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
        <CardTitle className="text-gray-300 text-sm font-medium">昨日の確定運用報酬</CardTitle>
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
          {error ? error : `${profitDate}の確定利益`}
        </p>
      </CardContent>
    </Card>
  )
}

export { LatestProfitCard }