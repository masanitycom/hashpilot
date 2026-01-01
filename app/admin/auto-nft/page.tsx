"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import {
  Loader2,
  ArrowLeft,
  Gift,
  Search,
  Download,
  Calendar,
  User,
  TrendingUp
} from "lucide-react"
import { supabase } from "@/lib/supabase"
import Link from "next/link"

interface AutoNftRecord {
  id: string
  user_id: string
  email: string
  nft_type: string
  acquired_date: string
  created_at: string
  cycle_number: number | null
  // affiliate_cycleから
  current_auto_nft_count: number
  current_manual_nft_count: number
  current_total_nft_count: number
  referral_total: number  // 紹介報酬累計
  phase: string
}

interface Stats {
  total_auto_nft: number
  users_with_auto_nft: number
  this_month_count: number
  last_month_count: number
}

export default function AdminAutoNftPage() {
  const [records, setRecords] = useState<AutoNftRecord[]>([])
  const [stats, setStats] = useState<Stats | null>(null)
  const [searchTerm, setSearchTerm] = useState("")
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")
  const router = useRouter()

  useEffect(() => {
    checkAuth()
  }, [])

  const checkAuth = async () => {
    try {
      const { data: { session }, error: sessionError } = await supabase.auth.getSession()

      if (sessionError || !session?.user) {
        router.push("/login")
        return
      }

      // 管理者チェック
      const email = session.user.email
      if (email !== "basarasystems@gmail.com" && email !== "support@dshsupport.biz") {
        const { data: adminCheck } = await supabase.rpc("is_admin", {
          user_email: email,
          user_uuid: null,
        })
        if (!adminCheck) {
          router.push("/dashboard")
          return
        }
      }

      fetchData()
    } catch (error) {
      console.error("Auth check error:", error)
      router.push("/login")
    }
  }

  const fetchData = async () => {
    try {
      setLoading(true)
      setError("")

      // 自動NFT一覧を取得
      const { data: nftData, error: nftError } = await supabase
        .from("nft_master")
        .select("id, user_id, nft_type, acquired_date, created_at")
        .eq("nft_type", "auto")
        .is("buyback_date", null)
        .order("acquired_date", { ascending: false })

      if (nftError) throw nftError

      if (!nftData || nftData.length === 0) {
        setRecords([])
        setStats({
          total_auto_nft: 0,
          users_with_auto_nft: 0,
          this_month_count: 0,
          last_month_count: 0
        })
        setLoading(false)
        return
      }

      // ユーザー情報を取得
      const userIds = [...new Set(nftData.map(n => n.user_id))]
      const { data: usersData } = await supabase
        .from("users")
        .select("user_id, email")
        .in("user_id", userIds)

      // affiliate_cycle情報を取得
      const { data: cycleData } = await supabase
        .from("affiliate_cycle")
        .select("user_id, auto_nft_count, manual_nft_count, total_nft_count, cum_usdt, phase")
        .in("user_id", userIds)

      // purchases情報を取得（cycle_number_at_purchase）
      const { data: purchasesData } = await supabase
        .from("purchases")
        .select("user_id, cycle_number_at_purchase, purchase_date")
        .eq("nft_type", "auto")
        .in("user_id", userIds)

      // データを結合
      const enrichedRecords = nftData.map(nft => {
        const user = usersData?.find(u => u.user_id === nft.user_id)
        const cycle = cycleData?.find(c => c.user_id === nft.user_id)
        const purchase = purchasesData?.find(p =>
          p.user_id === nft.user_id &&
          p.purchase_date === nft.acquired_date
        )

        return {
          ...nft,
          email: user?.email || "",
          cycle_number: purchase?.cycle_number_at_purchase || null,
          current_auto_nft_count: cycle?.auto_nft_count || 0,
          current_manual_nft_count: cycle?.manual_nft_count || 0,
          current_total_nft_count: cycle?.total_nft_count || 0,
          referral_total: cycle?.cum_usdt || 0,
          phase: cycle?.phase || "-"
        }
      })

      setRecords(enrichedRecords)

      // 統計情報を計算
      const now = new Date()
      const thisMonthStart = new Date(now.getFullYear(), now.getMonth(), 1)
      const lastMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1)
      const lastMonthEnd = new Date(now.getFullYear(), now.getMonth(), 0)

      const thisMonthCount = enrichedRecords.filter(r =>
        new Date(r.acquired_date) >= thisMonthStart
      ).length

      const lastMonthCount = enrichedRecords.filter(r => {
        const date = new Date(r.acquired_date)
        return date >= lastMonthStart && date <= lastMonthEnd
      }).length

      setStats({
        total_auto_nft: enrichedRecords.length,
        users_with_auto_nft: new Set(enrichedRecords.map(r => r.user_id)).size,
        this_month_count: thisMonthCount,
        last_month_count: lastMonthCount
      })

    } catch (err: any) {
      console.error("Error fetching data:", err)
      setError("データの取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  const exportCSV = () => {
    const headers = [
      "付与日", "ユーザーID", "メールアドレス", "サイクル番号",
      "自動NFT数", "手動NFT数", "合計NFT数",
      "紹介報酬累計", "次のNFTまで", "フェーズ"
    ]

    const csvData = filteredRecords.map(r => {
      const nextNftRemaining = r.referral_total >= 1100
        ? 2200 - r.referral_total
        : 2200 - r.referral_total
      return [
        r.acquired_date,
        r.user_id,
        r.email,
        r.cycle_number || "-",
        r.current_auto_nft_count,
        r.current_manual_nft_count,
        r.current_total_nft_count,
        "$" + r.referral_total.toFixed(2),
        "$" + Math.max(0, 2200 - r.referral_total).toFixed(2),
        r.phase === 'HOLD' ? 'ロック中' : r.phase === 'USDT' ? '払出可能' : r.phase
      ]
    })

    const bom = new Uint8Array([0xEF, 0xBB, 0xBF])
    const csvContent = [headers, ...csvData]
      .map(row => row.map(field => `"${field}"`).join(","))
      .join("\n")

    const blob = new Blob([bom, csvContent], { type: "text/csv;charset=utf-8;" })
    const link = document.createElement("a")
    link.href = URL.createObjectURL(blob)
    link.download = `auto_nft_history_${new Date().toISOString().split('T')[0]}.csv`
    link.click()
  }

  const filteredRecords = records.filter(r =>
    r.user_id.toLowerCase().includes(searchTerm.toLowerCase()) ||
    r.email.toLowerCase().includes(searchTerm.toLowerCase())
  )

  if (loading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="flex items-center space-x-2 text-white">
          <Loader2 className="h-6 w-6 animate-spin" />
          <span>読み込み中...</span>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-black">
      {/* ヘッダー */}
      <header className="bg-gray-800/50 backdrop-blur-sm border-b border-gray-700">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <Link href="/admin">
                <Button variant="ghost" size="sm" className="text-gray-300 hover:text-white">
                  <ArrowLeft className="h-4 w-4 mr-2" />
                  管理画面
                </Button>
              </Link>
              <div>
                <h1 className="text-xl font-bold text-white flex items-center">
                  <Gift className="h-6 w-6 mr-2 text-cyan-400" />
                  自動NFT付与履歴
                </h1>
                <p className="text-sm text-gray-400">紹介報酬$2,200到達による自動NFT付与の履歴</p>
              </div>
            </div>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-4 py-8">
        {/* 統計カード */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
            <Card className="bg-cyan-900/20 border-cyan-700/50">
              <CardContent className="p-4">
                <div className="flex items-center space-x-2">
                  <Gift className="h-6 w-6 text-cyan-400" />
                  <div>
                    <p className="text-xs text-cyan-300">自動NFT総数</p>
                    <p className="text-2xl font-bold text-cyan-400">{stats.total_auto_nft}</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="bg-green-900/20 border-green-700/50">
              <CardContent className="p-4">
                <div className="flex items-center space-x-2">
                  <User className="h-6 w-6 text-green-400" />
                  <div>
                    <p className="text-xs text-green-300">付与ユーザー数</p>
                    <p className="text-2xl font-bold text-green-400">{stats.users_with_auto_nft}</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="bg-blue-900/20 border-blue-700/50">
              <CardContent className="p-4">
                <div className="flex items-center space-x-2">
                  <Calendar className="h-6 w-6 text-blue-400" />
                  <div>
                    <p className="text-xs text-blue-300">今月の付与数</p>
                    <p className="text-2xl font-bold text-blue-400">{stats.this_month_count}</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="bg-purple-900/20 border-purple-700/50">
              <CardContent className="p-4">
                <div className="flex items-center space-x-2">
                  <TrendingUp className="h-6 w-6 text-purple-400" />
                  <div>
                    <p className="text-xs text-purple-300">先月の付与数</p>
                    <p className="text-2xl font-bold text-purple-400">{stats.last_month_count}</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        )}

        {/* 操作パネル */}
        <Card className="bg-gray-800 border-gray-700 mb-6">
          <CardContent className="p-4">
            <div className="flex flex-wrap items-center gap-4">
              <div className="flex-1 min-w-64">
                <div className="relative">
                  <Search className="h-4 w-4 absolute left-3 top-3 text-gray-400" />
                  <Input
                    placeholder="ユーザーID・メールアドレスで検索..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="pl-10 bg-gray-700 border-gray-600 text-white"
                  />
                </div>
              </div>

              <Button
                onClick={exportCSV}
                variant="outline"
                className="border-gray-600 text-black bg-white hover:bg-gray-100"
              >
                <Download className="h-4 w-4 mr-2" />
                CSV出力
              </Button>

              <Button
                onClick={fetchData}
                variant="outline"
                className="border-gray-600 text-gray-300 hover:text-white"
              >
                更新
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* 一覧テーブル */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white">
              自動NFT付与一覧 ({filteredRecords.length}件)
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-700">
                    <th className="text-left py-3 px-2 text-gray-300">付与日</th>
                    <th className="text-left py-3 px-2 text-gray-300">ユーザー</th>
                    <th className="text-center py-3 px-2 text-gray-300">サイクル</th>
                    <th className="text-center py-3 px-2 text-gray-300">NFT内訳</th>
                    <th className="text-right py-3 px-2 text-gray-300">紹介報酬累計</th>
                    <th className="text-right py-3 px-2 text-gray-300">次のNFTまで</th>
                    <th className="text-center py-3 px-2 text-gray-300">状態</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredRecords.map((record) => (
                    <tr key={record.id} className="border-b border-gray-700/50 hover:bg-gray-700/20">
                      <td className="py-3 px-2">
                        <div className="text-white">
                          {new Date(record.acquired_date).toLocaleDateString('ja-JP')}
                        </div>
                        <div className="text-xs text-gray-500">
                          {new Date(record.created_at).toLocaleTimeString('ja-JP')}
                        </div>
                      </td>
                      <td className="py-3 px-2">
                        <div className="font-medium text-white">{record.user_id}</div>
                        <div className="text-xs text-gray-400">{record.email}</div>
                      </td>
                      <td className="py-3 px-2 text-center">
                        {record.cycle_number ? (
                          <Badge className="bg-cyan-600 text-white">
                            #{record.cycle_number}
                          </Badge>
                        ) : (
                          <span className="text-gray-500">-</span>
                        )}
                      </td>
                      <td className="py-3 px-2 text-center">
                        <div className="text-gray-300">
                          <span className="text-blue-400">{record.current_manual_nft_count}手動</span>
                          {" + "}
                          <span className="text-cyan-400">{record.current_auto_nft_count}自動</span>
                          {" = "}
                          <span className="text-white font-bold">{record.current_total_nft_count}</span>
                        </div>
                      </td>
                      <td className="py-3 px-2 text-right">
                        <span className="text-orange-400 font-medium">
                          ${record.referral_total.toFixed(2)}
                        </span>
                      </td>
                      <td className="py-3 px-2 text-right">
                        <span className={`font-medium ${
                          2200 - record.referral_total <= 500 ? 'text-green-400' : 'text-gray-400'
                        }`}>
                          ${Math.max(0, 2200 - record.referral_total).toFixed(2)}
                        </span>
                        {2200 - record.referral_total <= 500 && record.referral_total < 2200 && (
                          <div className="text-xs text-green-400">もうすぐ!</div>
                        )}
                      </td>
                      <td className="py-3 px-2 text-center">
                        {record.phase === 'USDT' ? (
                          <Badge className="bg-green-600 text-white">💰 払出可能</Badge>
                        ) : record.phase === 'HOLD' ? (
                          <Badge className="bg-orange-600 text-white">🔒 ロック中</Badge>
                        ) : (
                          <Badge className="bg-gray-600 text-white">-</Badge>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>

              {filteredRecords.length === 0 && (
                <div className="text-center py-8 text-gray-400">
                  自動NFT付与の履歴がありません
                </div>
              )}
            </div>
          </CardContent>
        </Card>

        {error && (
          <div className="mt-4 p-4 bg-red-900/20 border border-red-500/50 rounded-lg">
            <p className="text-red-200">{error}</p>
          </div>
        )}
      </div>
    </div>
  )
}
