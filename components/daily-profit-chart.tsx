"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceLine } from "recharts"
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
      console.log('正確な利益計算確認 - User:', userId)
      
      // 個人利益データの取得
      const { data: dailyProfitData, error } = await supabase
        .from('user_daily_profit')
        .select('date, daily_profit, yield_rate, user_rate, phase')
        .eq('user_id', userId)
        .gte('date', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0])
        .order('date', { ascending: true })
      
      // affiliate_cycleデータの取得
      const { data: cycleData, error: cycleError } = await supabase
        .from('affiliate_cycle')
        .select('cum_usdt, available_usdt, total_nft_count, phase')
        .eq('user_id', userId)
        .single()
      
      // 購入情報の取得
      const { data: purchases, error: purchaseError } = await supabase
        .from('purchases')
        .select('admin_approved_at, nft_quantity, amount_usd')
        .eq('user_id', userId)
        .eq('admin_approved', true)
        .order('admin_approved_at', { ascending: false })
      
      console.log('=== 利益計算確認 ===')
      console.log('個人利益データ:', dailyProfitData)
      console.log('サイクルデータ:', cycleData)
      console.log('購入データ:', purchases)
      console.log('エラー:', error, cycleError, purchaseError)
      
      // 管理者チェック
      const { data: adminCheck } = await supabase
        .from('admins')
        .select('user_id, role')
        .eq('user_id', userId)
      
      const isAdmin = adminCheck && adminCheck.length > 0
      console.log('管理者チェック:', isAdmin, adminCheck)
      
      // 運用開始日の計算
      if (purchases && purchases.length > 0) {
        const latestApproval = purchases[0].admin_approved_at
        const operationStart = new Date(latestApproval)
        operationStart.setDate(operationStart.getDate() + 15)
        
        console.log('承認日:', new Date(latestApproval).toLocaleDateString())
        console.log('運用開始予定日:', operationStart.toLocaleDateString())
        console.log('現在運用中:', new Date() >= operationStart)
      }

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
            pnl: parseFloat(item.daily_profit) || 0,
            formattedDate: date.toLocaleDateString('ja-JP', { month: 'short', day: 'numeric' })
          }
        })
        
        setData(formattedData)
        
        // 最新の日利を設定
        if (formattedData.length > 0) {
          setCurrentPNL(formattedData[formattedData.length - 1].pnl)
        }
        
        // 計算確認のログ
        const totalProfit = dailyProfitData.reduce((sum, item) => sum + parseFloat(item.daily_profit || 0), 0)
        console.log('個人利益合計:', totalProfit.toFixed(3))
        console.log('サイクル累積:', cycleData ? parseFloat(cycleData.cum_usdt || 0).toFixed(3) : '0.000')
      } else {
        // データが存在しない場合は0のデータを表示
        console.log('利益データなし - 管理者:', isAdmin)
        const emptyData: DailyPNLData[] = []
        const today = new Date()
        for (let i = 29; i >= 0; i--) {
          const date = new Date(today)
          date.setDate(date.getDate() - i)
          emptyData.push({
            date: `${String(date.getMonth() + 1).padStart(2, '0')}/${String(date.getDate()).padStart(2, '0')}`,
            pnl: 0,
            formattedDate: date.toLocaleDateString('ja-JP', { month: 'short', day: 'numeric' })
          })
        }
        setData(emptyData)
        setCurrentPNL(0)
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
              domain={['dataMin - 2', 'dataMax + 2']}
            />
            <ReferenceLine 
              y={0} 
              stroke="#6B7280" 
              strokeDasharray="3 3" 
              strokeWidth={1}
              label={{ value: "0", position: "insideLeft", fill: "#9CA3AF", fontSize: 10 }}
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
              stroke="url(#colorPnl)"
              strokeWidth={2.5}
              dot={(props) => {
                const { cx, cy, payload } = props
                return (
                  <circle
                    cx={cx}
                    cy={cy}
                    r={3}
                    fill={payload.pnl >= 0 ? "#10B981" : "#EF4444"}
                    stroke="#1F2937"
                    strokeWidth={1}
                  />
                )
              }}
              activeDot={{
                r: 5,
                fill: "#FCD34D",
                stroke: "#1F2937",
                strokeWidth: 2,
              }}
            />
            <defs>
              <linearGradient id="colorPnl" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#10B981" stopOpacity={1} />
                <stop offset="50%" stopColor="#FCD34D" stopOpacity={1} />
                <stop offset="100%" stopColor="#EF4444" stopOpacity={1} />
              </linearGradient>
            </defs>
          </LineChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  )
}

export default DailyProfitChart
