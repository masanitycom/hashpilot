"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { RefreshCw, Zap, TrendingUp, Calendar, Package } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface AutoNFTGrant {
  id: string
  user_id: string
  email: string
  full_name: string | null
  nft_quantity: number
  amount_usd: number
  granted_at: string
  created_at: string
  has_approved_nft: boolean
  current_auto_nft_count: number
  nft_details: Array<{
    nft_sequence: number
    nft_value: number
    acquired_date: string
  }> | null
}

export default function AdminAutoNFTGrantsPage() {
  const [grants, setGrants] = useState<AutoNFTGrant[]>([])
  const [loading, setLoading] = useState(true)
  const [isAdmin, setIsAdmin] = useState(false)
  const [error, setError] = useState("")
  const router = useRouter()

  useEffect(() => {
    checkAdminAccess()
  }, [])

  const checkAdminAccess = async () => {
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) {
        router.push("/login")
        return
      }

      // 緊急対応: basarasystems@gmail.com または support@dshsupport.biz のアクセス許可
      if (user.email === "basarasystems@gmail.com" || user.email === "support@dshsupport.biz") {
        setIsAdmin(true)
        fetchGrants()
        return
      }

      // 管理者権限チェック
      const { data: adminCheck, error: adminError } = await supabase.rpc("is_admin", {
        user_email: user.email,
      })

      if (adminError) {
        console.error("Admin check error:", adminError)
        const { data: userCheck, error: userError } = await supabase
          .from("users")
          .select("is_admin")
          .eq("email", user.email)
          .single()

        if (!userError && userCheck?.is_admin) {
          setIsAdmin(true)
          fetchGrants()
        } else {
          router.push("/dashboard")
        }
        return
      }

      if (adminCheck) {
        setIsAdmin(true)
        fetchGrants()
      } else {
        router.push("/dashboard")
      }
    } catch (error) {
      console.error("Admin access check error:", error)
      router.push("/dashboard")
    }
  }

  const fetchGrants = async () => {
    try {
      setLoading(true)
      setError("")

      const { data, error } = await supabase
        .from("admin_auto_nft_grants_view")
        .select("*")
        .order("created_at", { ascending: false })

      if (error) {
        console.error("Fetch grants error:", error)
        throw error
      }

      setGrants(data || [])
    } catch (error: any) {
      console.error("Error fetching grants:", error)
      setError(`自動NFT付与履歴の取得に失敗しました: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const formatDate = (dateString: string) => {
    if (!dateString) return "N/A"
    const date = new Date(dateString)
    return date.toLocaleString("ja-JP", {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    })
  }

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <div className="text-center">
          <p className="text-xl">アクセス権限を確認しています...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-black text-white p-8">
      <div className="max-w-7xl mx-auto space-y-6">
        {/* ヘッダー */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold flex items-center gap-2">
              <Zap className="h-8 w-8 text-purple-400" />
              自動NFT付与履歴
            </h1>
            <p className="text-gray-400 mt-2">
              紹介報酬2200ドル到達により自動付与されたNFTの履歴
            </p>
          </div>
          <div className="flex gap-2">
            <Button onClick={() => router.push("/admin/purchases")} variant="outline">
              手動購入管理
            </Button>
            <Button onClick={fetchGrants} size="sm" disabled={loading}>
              <RefreshCw className={`h-4 w-4 mr-2 ${loading ? "animate-spin" : ""}`} />
              更新
            </Button>
          </div>
        </div>

        {/* 統計カード */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Card className="bg-gray-800 border-gray-700">
            <CardContent className="p-6">
              <div className="flex items-center gap-3">
                <div className="bg-purple-900/30 p-3 rounded-lg">
                  <Package className="h-6 w-6 text-purple-400" />
                </div>
                <div>
                  <p className="text-sm text-gray-400">総付与回数</p>
                  <p className="text-2xl font-bold">{grants.length}回</p>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gray-800 border-gray-700">
            <CardContent className="p-6">
              <div className="flex items-center gap-3">
                <div className="bg-blue-900/30 p-3 rounded-lg">
                  <TrendingUp className="h-6 w-6 text-blue-400" />
                </div>
                <div>
                  <p className="text-sm text-gray-400">総付与NFT数</p>
                  <p className="text-2xl font-bold">
                    {grants.reduce((sum, g) => sum + g.nft_quantity, 0)}個
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gray-800 border-gray-700">
            <CardContent className="p-6">
              <div className="flex items-center gap-3">
                <div className="bg-green-900/30 p-3 rounded-lg">
                  <Calendar className="h-6 w-6 text-green-400" />
                </div>
                <div>
                  <p className="text-sm text-gray-400">総付与金額</p>
                  <p className="text-2xl font-bold">
                    ${grants.reduce((sum, g) => sum + g.amount_usd, 0).toLocaleString()}
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* エラー表示 */}
        {error && (
          <Card className="bg-red-900/20 border-red-500">
            <CardContent className="p-4">
              <p className="text-red-300">{error}</p>
            </CardContent>
          </Card>
        )}

        {/* 付与履歴テーブル */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Package className="h-5 w-5" />
              自動付与履歴一覧
            </CardTitle>
          </CardHeader>
          <CardContent>
            {loading ? (
              <div className="text-center py-8">
                <RefreshCw className="h-8 w-8 animate-spin mx-auto text-gray-400" />
                <p className="mt-2 text-gray-400">読み込み中...</p>
              </div>
            ) : grants.length === 0 ? (
              <div className="text-center py-8 text-gray-400">
                <Package className="h-12 w-12 mx-auto mb-2 opacity-50" />
                <p>自動付与履歴はありません</p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-gray-700">
                      <th className="text-left p-3 text-sm font-medium text-gray-400">付与日時</th>
                      <th className="text-left p-3 text-sm font-medium text-gray-400">ユーザー</th>
                      <th className="text-left p-3 text-sm font-medium text-gray-400">メール</th>
                      <th className="text-right p-3 text-sm font-medium text-gray-400">付与NFT数</th>
                      <th className="text-right p-3 text-sm font-medium text-gray-400">現在の自動NFT</th>
                      <th className="text-right p-3 text-sm font-medium text-gray-400">金額</th>
                      <th className="text-center p-3 text-sm font-medium text-gray-400">ステータス</th>
                    </tr>
                  </thead>
                  <tbody>
                    {grants.map((grant) => (
                      <tr key={grant.id} className="border-b border-gray-700 hover:bg-gray-700/30">
                        <td className="p-3 text-sm text-gray-200">{formatDate(grant.granted_at)}</td>
                        <td className="p-3">
                          <div className="flex flex-col">
                            <span className="font-medium text-white">{grant.full_name || "未設定"}</span>
                            <span className="text-xs text-gray-400">{grant.user_id}</span>
                          </div>
                        </td>
                        <td className="p-3 text-sm text-gray-200">{grant.email}</td>
                        <td className="p-3 text-right">
                          <Badge variant="secondary" className="bg-purple-900/30 text-purple-300">
                            {grant.nft_quantity}個
                          </Badge>
                        </td>
                        <td className="p-3 text-right">
                          <span className="text-sm text-gray-300">{grant.current_auto_nft_count}個</span>
                        </td>
                        <td className="p-3 text-right font-medium text-white">
                          ${grant.amount_usd.toLocaleString()}
                        </td>
                        <td className="p-3 text-center">
                          {grant.has_approved_nft ? (
                            <Badge className="bg-green-600">運用中</Badge>
                          ) : (
                            <Badge variant="secondary">未承認</Badge>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>

        {/* NFT詳細情報（オプション） */}
        {grants.length > 0 && (
          <Card className="bg-gray-800 border-gray-700">
            <CardHeader>
              <CardTitle className="text-sm">💡 注意事項</CardTitle>
            </CardHeader>
            <CardContent className="text-sm text-gray-400 space-y-2">
              <p>• 自動NFT付与は、紹介報酬が2200ドルに到達した際に実行されます</p>
              <p>• 付与されたNFTは即座に運用開始され、日利計算の対象となります</p>
              <p>• 各付与により、ユーザーは1100ドルを受取可能額として獲得します</p>
              <p>• この履歴は参照用であり、編集や承認操作は不要です</p>
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  )
}
