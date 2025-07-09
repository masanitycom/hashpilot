"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from "recharts"
import { RefreshCw, Calendar } from "lucide-react"

interface MonthlyRewardData {
  month: string
  reward: number
  referrals: number
}

interface MonthlyRewardsHistoryProps {
  userId: string
}

export function MonthlyRewardsHistory({ userId }: MonthlyRewardsHistoryProps) {
  const [data, setData] = useState<MonthlyRewardData[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")

  useEffect(() => {
    if (userId) {
      fetchMonthlyRewardsData()
    }
  }, [userId])

  const fetchMonthlyRewardsData = async () => {
    try {
      setLoading(true)
      setError("")

      // サンプルデータを生成して表示
      const sampleData = generateSampleData()
      setData(sampleData)
    } catch (err: any) {
      console.error("Monthly rewards fetch error:", err)
      setError("データの取得中にエラーが発生しました")
      const sampleData = generateSampleData()
      setData(sampleData)
    } finally {
      setLoading(false)
    }
  }

  const generateSampleData = (): MonthlyRewardData[] => {
    const months = ["1月", "2月", "3月", "4月", "5月", "6月"]
    return months.map((month, index) => ({
      month,
      reward: Math.random() * 500 + 200,
      referrals: Math.floor(Math.random() * 10) + 1,
    }))
  }

  if (loading) {
    return (
      <Card className="bg-gray-800 border-gray-700 text-white">
        <CardHeader>
          <CardTitle className="flex items-center">
            <Calendar className="h-5 w-5 mr-2" />
            月次報酬履歴
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
      <CardHeader>
        <CardTitle className="flex items-center">
          <Calendar className="h-5 w-5 mr-2" />
          月次報酬履歴
        </CardTitle>
        <CardDescription className="text-gray-400">過去6ヶ月の紹介報酬</CardDescription>
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={data}>
            <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
            <XAxis dataKey="month" stroke="#9CA3AF" fontSize={12} />
            <YAxis stroke="#9CA3AF" fontSize={12} tickFormatter={(value) => `$${value.toFixed(0)}`} />
            <Tooltip
              contentStyle={{
                backgroundColor: "#1F2937",
                border: "1px solid #374151",
                borderRadius: "8px",
                color: "#F9FAFB",
              }}
              formatter={(value: number) => [`$${value.toFixed(2)}`, "報酬"]}
            />
            <Bar dataKey="reward" fill="#8B5CF6" radius={[4, 4, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  )
}

export default MonthlyRewardsHistory
