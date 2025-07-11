"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Users, Shield, RefreshCw, Search, TrendingUp, Network } from "lucide-react"
import { supabase } from "@/lib/supabase"
import Link from "next/link"

interface User {
  id: string
  user_id: string
  email: string
  full_name: string | null
  coinw_uid: string | null
  referrer_user_id: string | null
  is_active: boolean
  has_approved_nft: boolean
  total_purchases: number
  created_at: string
}

interface ReferralNode {
  level_num: number
  user_id: string
  email: string
  personal_purchases: number
  subtree_total: number
  referrer_id: string
  direct_referrals_count: number
}

interface ReferralStats {
  total_direct_referrals: number
  total_indirect_referrals: number
  total_referral_purchases: number
  max_tree_depth: number
}

export default function AdminReferralsPage() {
  const [users, setUsers] = useState<User[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState("")
  const [selectedUserId, setSelectedUserId] = useState("")
  const [treeData, setTreeData] = useState<ReferralNode[]>([])
  const [treeStats, setTreeStats] = useState<ReferralStats | null>(null)
  const [treeLoading, setTreeLoading] = useState(false)
  const [currentUser, setCurrentUser] = useState<any>(null)
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

      setCurrentUser(user)

      // 緊急対応: basarasystems@gmail.com または support@dshsupport.biz のアクセス許可
      if (user.email === "basarasystems@gmail.com" || user.email === "support@dshsupport.biz") {
        setIsAdmin(true)
        fetchUsers()
        return
      }

      const { data: adminCheck, error: adminError } = await supabase.rpc("is_admin", {
        user_email: user.email,
      })

      if (adminError) {
        console.error("Admin check error:", adminError)
        // フォールバック: usersテーブルのis_adminフィールドをチェック
        const { data: userCheck, error: userError } = await supabase
          .from("users")
          .select("is_admin")
          .eq("email", user.email)
          .single()
        
        if (!userError && userCheck?.is_admin) {
          setIsAdmin(true)
          fetchUsers()
          return
        }
        
        setError("管理者権限の確認でエラーが発生しました")
        return
      }

      if (!adminCheck) {
        // フォールバック: usersテーブルのis_adminフィールドをチェック
        const { data: userCheck, error: userError } = await supabase
          .from("users")
          .select("is_admin")
          .eq("email", user.email)
          .single()
        
        if (!userError && userCheck?.is_admin) {
          setIsAdmin(true)
          fetchUsers()
          return
        }
        
        alert("管理者権限がありません")
        router.push("/dashboard")
        return
      }

      setIsAdmin(true)
      fetchUsers()
    } catch (error) {
      console.error("Admin access check error:", error)
      setError("管理者権限の確認でエラーが発生しました")
    }
  }

  const fetchUsers = async () => {
    try {
      setLoading(true)
      setError("")

      const { data, error } = await supabase.from("users").select("*").order("total_purchases", { ascending: false })

      if (error) {
        console.error("Fetch users error:", error)
        throw error
      }

      console.log("Fetched users:", data)
      setUsers(data || [])
    } catch (error: any) {
      console.error("Error fetching users:", error)
      setError(`ユーザーデータの取得に失敗しました: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const fetchReferralTree = async (userId: string) => {
    try {
      setTreeLoading(true)
      setTreeData([])
      setTreeStats(null)

      console.log("Fetching referral tree for user:", userId)

      // 紹介ツリーデータを取得
      const { data: treeResult, error: treeError } = await supabase.rpc("get_referral_tree", {
        root_user_id: userId,
      })

      if (treeError) {
        console.error("Tree data error:", treeError)
        throw treeError
      }

      console.log("Tree result:", treeResult)

      // 統計データを取得
      const { data: statsResult, error: statsError } = await supabase.rpc("get_referral_stats", {
        target_user_id: userId,
      })

      if (statsError) {
        console.error("Stats data error:", statsError)
        // 統計エラーは無視して続行
      }

      console.log("Stats result:", statsResult)

      setTreeData(treeResult || [])
      setTreeStats(statsResult?.[0] || null)
    } catch (error: any) {
      console.error("Error fetching referral tree:", error)
      alert(`紹介ツリーの取得に失敗しました: ${error.message}`)
    } finally {
      setTreeLoading(false)
    }
  }

  const renderTreeNode = (node: ReferralNode) => {
    const indentLevel = (node.level_num - 1) * 20
    const totalAmount = node.personal_purchases + node.subtree_total

    return (
      <div
        key={node.user_id}
        className="border-l-4 border-blue-500 pl-4 py-2 mb-3"
        style={{ marginLeft: `${indentLevel}px` }}
      >
        <div className="bg-gray-700 rounded-lg p-4">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center space-x-3">
              <Badge variant="outline" className="bg-blue-600 text-white">
                Lv.{node.level_num}
              </Badge>
              <div>
                <div className="font-semibold text-white">{node.user_id}</div>
                <div className="text-sm text-gray-300">{node.email}</div>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-3 gap-4 text-sm">
            <div className="text-center">
              <div className="text-gray-400">個人購入</div>
              <div className="font-semibold text-green-400">${node.personal_purchases.toFixed(2)}</div>
            </div>
            <div className="text-center">
              <div className="text-gray-400">下位合計</div>
              <div className="font-semibold text-blue-400">${node.subtree_total.toFixed(2)}</div>
            </div>
            <div className="text-center">
              <div className="text-gray-400">総合計</div>
              <div className="font-semibold text-yellow-400">${totalAmount.toFixed(2)}</div>
            </div>
          </div>
        </div>
      </div>
    )
  }

  const filteredUsers = users.filter(
    (user) =>
      user.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
      user.user_id.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (user.full_name && user.full_name.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (user.coinw_uid && user.coinw_uid.toLowerCase().includes(searchTerm.toLowerCase())),
  )

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString("ja-JP")
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-white">管理者権限を確認中...</p>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-red-400">エラー</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p className="text-white">{error}</p>
            <div className="flex space-x-2">
              <Button onClick={checkAdminAccess} className="flex-1 bg-blue-600 hover:bg-blue-700 text-white">
                再試行
              </Button>
              <Button
                variant="outline"
                onClick={() => router.push("/dashboard")}
                className="flex-1 bg-gray-600 hover:bg-gray-700 text-white border-gray-600"
              >
                ダッシュボード
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    )
  }

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-red-400 flex items-center">
              <Shield className="w-5 h-5 mr-2" />
              アクセス拒否
            </CardTitle>
          </CardHeader>
          <CardContent className="text-white">
            <p>管理者権限が必要です。</p>
            <Button
              onClick={() => router.push("/dashboard")}
              className="mt-4 w-full bg-blue-600 hover:bg-blue-700 text-white"
            >
              ダッシュボードに戻る
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-900 p-4">
      <div className="max-w-7xl mx-auto">
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="text-white flex items-center">
                <Network className="w-5 h-5 mr-2" />
                紹介関係管理 - {currentUser?.email}
              </CardTitle>
              <div className="flex space-x-2">
                <Link href="/admin">
                  <Button
                    variant="outline"
                    size="sm"
                    className="bg-blue-600 hover:bg-blue-700 text-white border-blue-600"
                  >
                    管理者ダッシュボード
                  </Button>
                </Link>
                <Button onClick={fetchUsers} size="sm" className="bg-blue-600 hover:bg-blue-700 text-white">
                  <RefreshCw className="w-4 h-4 mr-2" />
                  更新
                </Button>
              </div>
            </div>
          </CardHeader>
          <CardContent>
            <div className="mb-6">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
                <Input
                  placeholder="ユーザーを検索してツリーを表示..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="pl-10 bg-gray-700 border-gray-600 text-white placeholder-gray-400"
                />
              </div>
            </div>

            <div className="grid md:grid-cols-2 gap-6">
              {/* ユーザーリスト */}
              <Card className="bg-gray-700 border-gray-600">
                <CardHeader>
                  <CardTitle className="text-white text-lg">ユーザーリスト ({filteredUsers.length}人)</CardTitle>
                </CardHeader>
                <CardContent className="max-h-96 overflow-y-auto">
                  {filteredUsers.length === 0 ? (
                    <div className="text-center py-8 text-gray-400">
                      <Users className="w-12 h-12 mx-auto mb-4 opacity-50" />
                      <p>ユーザーが見つかりません</p>
                    </div>
                  ) : (
                    <div className="space-y-2">
                      {filteredUsers.slice(0, 50).map((user) => (
                        <div
                          key={user.id}
                          className={`p-3 rounded-lg cursor-pointer transition-colors ${
                            selectedUserId === user.user_id
                              ? "bg-blue-600 text-white"
                              : "bg-gray-600 hover:bg-gray-500 text-white"
                          }`}
                          onClick={() => {
                            setSelectedUserId(user.user_id)
                            fetchReferralTree(user.user_id)
                          }}
                        >
                          <div className="flex items-center justify-between">
                            <div>
                              <div className="font-semibold">{user.user_id}</div>
                              <div className="text-sm opacity-75">{user.email}</div>
                              {user.coinw_uid && <div className="text-xs opacity-60">CoinW: {user.coinw_uid}</div>}
                            </div>
                            <div className="text-right">
                              <div className="text-sm font-semibold">${user.total_purchases.toFixed(2)}</div>
                              <div className="flex space-x-1">
                                {user.has_approved_nft && <Badge className="bg-green-600 text-xs">NFT</Badge>}
                                {user.coinw_uid && <Badge className="bg-purple-600 text-xs">CoinW</Badge>}
                                {user.referrer_user_id && <Badge className="bg-orange-600 text-xs">紹介</Badge>}
                              </div>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </CardContent>
              </Card>

              {/* 紹介ツリー表示 */}
              <Card className="bg-gray-700 border-gray-600">
                <CardHeader>
                  <CardTitle className="text-white text-lg flex items-center">
                    <TrendingUp className="w-5 h-5 mr-2" />
                    紹介ツリー
                    {selectedUserId && <span className="ml-2 text-blue-400">- {selectedUserId}</span>}
                  </CardTitle>
                </CardHeader>
                <CardContent className="max-h-96 overflow-y-auto">
                  {!selectedUserId ? (
                    <div className="text-center py-8 text-gray-400">
                      <Network className="w-12 h-12 mx-auto mb-4 opacity-50" />
                      <p>左側のユーザーを選択して紹介ツリーを表示</p>
                    </div>
                  ) : treeLoading ? (
                    <div className="text-center py-8">
                      <RefreshCw className="w-6 h-6 animate-spin mx-auto mb-4 text-blue-400" />
                      <p className="text-white">紹介ツリーを読み込み中...</p>
                    </div>
                  ) : treeData.length === 0 ? (
                    <div className="text-center py-8 text-gray-400">
                      <Users className="w-12 h-12 mx-auto mb-4 opacity-50" />
                      <p>このユーザーには紹介者がいません</p>
                    </div>
                  ) : (
                    <div className="space-y-2">
                      {/* 統計情報 */}
                      {treeStats && (
                        <div className="bg-gray-600 rounded-lg p-4 mb-4">
                          <div className="grid grid-cols-2 gap-4 text-center">
                            <div>
                              <div className="text-2xl font-bold text-blue-400">
                                {treeStats.total_direct_referrals + treeStats.total_indirect_referrals}
                              </div>
                              <div className="text-sm text-gray-300">総紹介人数</div>
                            </div>
                            <div>
                              <div className="text-2xl font-bold text-green-400">
                                ${treeStats.total_referral_purchases.toFixed(2)}
                              </div>
                              <div className="text-sm text-gray-300">総購入額</div>
                            </div>
                          </div>
                        </div>
                      )}

                      {/* ツリー表示 */}
                      {treeData.map(renderTreeNode)}
                    </div>
                  )}
                </CardContent>
              </Card>
            </div>

            {/* 全体統計 */}
            <Card className="mt-6 bg-gray-700 border-gray-600">
              <CardHeader>
                <CardTitle className="text-white text-lg">全体統計</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-4 gap-4 text-center">
                  <div>
                    <div className="text-2xl font-bold text-white">{users.length}</div>
                    <div className="text-sm text-gray-300">総ユーザー数</div>
                  </div>
                  <div>
                    <div className="text-2xl font-bold text-green-400">
                      {users.filter((u) => u.referrer_user_id).length}
                    </div>
                    <div className="text-sm text-gray-300">紹介経由ユーザー</div>
                  </div>
                  <div>
                    <div className="text-2xl font-bold text-blue-400">
                      {users.filter((u) => u.has_approved_nft).length}
                    </div>
                    <div className="text-sm text-gray-300">NFT購入済み</div>
                  </div>
                  <div>
                    <div className="text-2xl font-bold text-purple-400">{users.filter((u) => u.coinw_uid).length}</div>
                    <div className="text-sm text-gray-300">CoinW連携済み</div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
