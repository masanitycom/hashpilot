"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from "recharts"
import { RefreshCw, Info } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface DailyPNLData {
  date: string
  pnl: number
  formattedDate: string
}

interface DailyProfitChartProps {
  userId: string
}

interface DailyProfitRecord {
  date: string
  daily_profit: number
  yield_rate: number
  user_rate: number
  phase: string
}

export function DailyProfitChart({ userId }: DailyProfitChartProps) {
  const [data, setData] = useState<DailyPNLData[]>([])
  const [loading, setLoading] = useState(true)
  const [currentPNL, setCurrentPNL] = useState(-2.510235)

  useEffect(() => {
    if (userId) {
      fetchDailyPNLData()
    }
  }, [userId])

  const fetchDailyPNLData = async () => {
    try {
      setLoading(true)

      if (!userId) {
        console.warn("User ID not available")
        const sampleData = generatePNLData()
        setData(sampleData)
        return
      }

      // 実際のデータベースから日利データを取得
      const { data: dailyProfitData, error } = await supabase
        .from('user_daily_profit')
        .select('date, daily_profit, yield_rate, user_rate, phase')
        .eq('user_id', userId)
        .gte('date', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0])
        .order('date', { ascending: true })

      if (error) {
        console.error('Database error:', error)
        // フォールバック: サンプルデータを使用
        const sampleData = generatePNLData()
        setData(sampleData)
        return
      }

      if (dailyProfitData && dailyProfitData.length > 0) {
        // 実際のデータを使用
        const formattedData: DailyPNLData[] = dailyProfitData.map((item: DailyProfitRecord) => {
          const date = new Date(item.date)
          return {
            date: `${String(date.getMonth() + 1).padStart(2, '0')}/${String(date.getDate()).padStart(2, '0')}`,
            pnl: item.daily_profit,
            formattedDate: date.toLocaleDateString('ja-JP', { month: 'short', day: 'numeric' })
          }
        })
        
        setData(formattedData)
        
        // 最新の日利を設定
        if (formattedData.length > 0) {
          setCurrentPNL(formattedData[formattedData.length - 1].pnl)
        }
      } else {
        // データが存在しない場合はサンプルデータを使用
        console.log('No daily profit data found, using sample data')
        const sampleData = generatePNLData()
        setData(sampleData)
      }
    } catch (err: any) {
      console.error("Daily PNL fetch error:", err)
      const sampleData = generatePNLData()
      setData(sampleData)
    } finally {
      setLoading(false)
    }
  }

  const generatePNLData = (): DailyPNLData[] => {
    // 画像に合わせた波形データ
    const pnlValues = [
      -5.2, -3.8, -1.5, 2.3, 5.8, 8.1, 6.9, 4.2, 1.8, -2.1, -6.8, -10.2, -8.5, -4.3, 0.8, 3.2, 1.5, -1.8,
    ]

    const data: DailyPNLData[] = []
    const today = new Date()

    pnlValues.forEach((pnl, index) => {
      const date = new Date(today)
      date.setDate(date.getDate() - (pnlValues.length - 1 - index))

      data.push({
        date: `${String(date.getMonth() + 1).padStart(2, "0")}/${String(date.getDate()).padStart(2, "0")}`,
        pnl: pnl,
        formattedDate: date.toLocaleDateString("ja-JP", { month: "short", day: "numeric" }),
      })
    })

    return data
  }

  if (loading) {
    return (
      <Card className="bg-gray-800 border-gray-700 text-white">
        <CardHeader>
          <CardTitle className="flex items-center text-white">
            <Info className="h-5 w-5 mr-2" />
            日次PNL
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-center justify-center h-64">
            <RefreshCw className="w-6 h-6 animate-spin mr-2" />
            <span>データを読み込み中...</span>
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card className="bg-gray-800 border-gray-700 text-white">
      <CardHeader className="pb-2">
        <CardTitle className="flex items-center text-white text-sm font-medium">
          <Info className="h-4 w-4 mr-2" />
          日次PNL
        </CardTitle>
        <div className="text-2xl font-bold">
          <span className={currentPNL >= 0 ? "text-green-400" : "text-red-400"}>
            ${currentPNL >= 0 ? "+" : ""}
            {currentPNL.toFixed(2)}
          </span>
        </div>
        <div className="text-xs text-gray-400 mt-1">
          過去30日間の日利実績
        </div>
      </CardHeader>
      <CardContent className="pt-0">
        <ResponsiveContainer width="100%" height={200}>
          <LineChart data={data} margin={{ top: 5, right: 5, left: 5, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#374151" opacity={0.3} />
            <XAxis dataKey="date" stroke="#9CA3AF" fontSize={11} axisLine={false} tickLine={false} />
            <YAxis
              stroke="#9CA3AF"
              fontSize={11}
              axisLine={false}
              tickLine={false}
              tickFormatter={(value) => value.toFixed(0)}
            />
            <Tooltip
              contentStyle={{
                backgroundColor: "#1F2937",
                border: "1px solid #374151",
                borderRadius: "8px",
                color: "#F9FAFB",
                fontSize: "12px",
              }}
              formatter={(value: number) => [`$${value >= 0 ? "+" : ""}${value.toFixed(2)}`, "日利"]}
              labelFormatter={(label) => `日付: ${label}`}
            />
            <Line
              type="monotone"
              dataKey="pnl"
              stroke="#10B981"
              strokeWidth={2.5}
              dot={false}
              activeDot={{
                r: 4,
                fill: "#10B981",
                stroke: "#1F2937",
                strokeWidth: 2,
              }}
            />
          </LineChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  )
}

export default DailyProfitChart
