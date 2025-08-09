"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { DollarSign, TrendingUp, Loader2 } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface PersonalProfitCardProps {
  userId: string
  totalInvestment: number
}

interface ProfitData {
  yesterdayProfit: number
  monthlyProfit: number
}

export function PersonalProfitCard({ userId, totalInvestment }: PersonalProfitCardProps) {
  const [profitData, setProfitData] = useState<ProfitData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")

  useEffect(() => {
    if (userId) {
      fetchPersonalProfit()
    }
  }, [userId, totalInvestment])

  const fetchPersonalProfit = async () => {
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

      // 昨日の個人利益を取得（daily_profitは既に個人投資額に対する利益）
      const { data: yesterdayData, error: yesterdayError } = await supabase
        .from('user_daily_profit')
        .select('daily_profit')
        .eq('user_id', userId)
        .eq('date', yesterdayStr)
        .maybeSingle()

      if (yesterdayError && yesterdayError.code !== 'PGRST116' && yesterdayError.code !== '42P01') {
        console.log('Yesterday profit error:', yesterdayError)
        throw yesterdayError
      }

      // 今月の個人利益累計を取得
      const { data: monthlyData, error: monthlyError } = await supabase
        .from('user_daily_profit')
        .select('daily_profit')
        .eq('user_id', userId)
        .gte('date', monthStart)
        .lte('date', monthEnd)

      if (monthlyError && monthlyError.code !== 'PGRST116' && monthlyError.code !== '42P01') {
        console.log('Monthly profit error:', monthlyError)
        throw monthlyError
      }

      // daily_profitは既に個人投資額に対する実際の利益なので、そのまま使用
      const yesterdayPersonalProfit = yesterdayData ? parseFloat(yesterdayData.daily_profit) : 0
      const monthlyPersonalProfit = monthlyData ? 
        monthlyData.reduce((sum, record) => sum + parseFloat(record.daily_profit), 0) : 0

      setProfitData({
        yesterdayProfit: yesterdayPersonalProfit,
        monthlyProfit: monthlyPersonalProfit
      })

    } catch (err: any) {
      console.error("Personal profit fetch error:", err)
      setError("個人利益データの取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardHeader className="pb-3">
          <CardTitle className="text-gray-300 text-sm font-medium">個人投資利益</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-center space-x-2">
            <Loader2 className="h-5 w-5 text-green-400 animate-spin" />
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
          <DollarSign className="h-4 w-4 text-green-400" />
          個人投資利益
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="text-xs text-gray-400 mb-3">
          投資額: ${(totalInvestment || 0).toLocaleString()}
        </div>
        
        {/* 昨日の利益 */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-xs text-gray-400">昨日の利益</span>
            <div className="flex items-center space-x-1">
              <TrendingUp className="h-3 w-3 text-green-400" />
              <span className={`text-sm font-semibold ${
                (profitData?.yesterdayProfit || 0) >= 0 ? "text-green-400" : "text-red-400"
              }`}>
                ${(profitData?.yesterdayProfit || 0).toFixed(3)}
              </span>
            </div>
          </div>
        </div>

        {/* 今月の累計利益 */}
        <div className="space-y-2 border-t border-gray-600 pt-3">
          <div className="flex items-center justify-between">
            <span className="text-xs text-gray-400">今月累計</span>
            <div className="flex items-center space-x-1">
              <TrendingUp className="h-3 w-3 text-blue-400" />
              <span className={`text-lg font-bold ${
                (profitData?.monthlyProfit || 0) >= 0 ? "text-blue-400" : "text-red-400"
              }`}>
                ${(profitData?.monthlyProfit || 0).toFixed(3)}
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