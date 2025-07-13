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
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string>("")
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

      console.log('Monthly profit query:', {
        userId,
        monthStart,
        monthEnd
      })

      // 個人の今月の累積利益を取得
      const { data: profitData, error: profitError } = await supabase
        .from('user_daily_profit')
        .select('daily_profit')
        .eq('user_id', userId)
        .gte('date', monthStart)
        .lte('date', monthEnd)

      if (profitError) {
        throw profitError
      }

      console.log('Monthly profit data:', profitData)

      // 個人利益を計算
      const personalProfit = profitData?.reduce((sum, record) => {
        const dailyValue = parseFloat(record.daily_profit) || 0
        console.log(`Daily profit for ${record.date || 'unknown'}: ${record.daily_profit} -> parsed: ${dailyValue}`)
        return sum + dailyValue
      }, 0) || 0

      // 紹介報酬を取得
      const { data: referralData, error: referralError } = await supabase
        .rpc('get_referral_profits', {
          p_user_id: userId,
          p_month_start: monthStart,
          p_month_end: monthEnd
        })

      let referralProfit = 0
      if (referralData) {
        referralProfit = referralData.reduce((sum, row) => sum + parseFloat(row.monthly_profit), 0)
      }

      // 合計利益を計算
      const totalProfit = personalProfit + referralProfit

      console.log('Profit data array:', profitData)
      console.log('Total monthly profit calculated:', totalProfit)
      console.log('Profit data length:', profitData?.length)
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
          <span className={`text-2xl font-bold ${profit >= 0 ? "text-purple-400" : "text-red-400"}`}>
            ${profit >= 0 ? "+" : ""}
            {profit.toFixed(3)}
          </span>
        </div>
        <p className="text-xs text-gray-500 mt-1">
          {error ? error : `${currentMonth}の累積利益`}
        </p>
      </CardContent>
    </Card>
  )
}

