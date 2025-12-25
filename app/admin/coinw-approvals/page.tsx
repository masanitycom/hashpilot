"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import {
  Loader2,
  ArrowLeft,
  CheckCircle,
  XCircle,
  Clock,
  Search,
  RefreshCw
} from "lucide-react"
import { supabase } from "@/lib/supabase"
import Link from "next/link"

interface CoinwUidChange {
  id: string
  user_id: string
  old_coinw_uid: string | null
  new_coinw_uid: string
  status: string
  created_at: string
  reviewed_at: string | null
  reviewed_by: string | null
  rejection_reason: string | null
  // usersテーブルから取得
  email?: string
}

export default function CoinwApprovalsPage() {
  const [changes, setChanges] = useState<CoinwUidChange[]>([])
  const [loading, setLoading] = useState(true)
  const [processing, setProcessing] = useState<string | null>(null)
  const [error, setError] = useState("")
  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] = useState<"all" | "pending" | "approved" | "rejected">("pending")
  const [currentUser, setCurrentUser] = useState<any>(null)
  const router = useRouter()

  useEffect(() => {
    checkAuth()
  }, [])

  useEffect(() => {
    if (currentUser) {
      fetchChanges()
    }
  }, [currentUser, statusFilter])

  const checkAuth = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session?.user) {
        router.push("/admin-login")
        return
      }

      // 管理者チェック
      if (session.user.email !== "basarasystems@gmail.com" && session.user.email !== "support@dshsupport.biz") {
        const { data: adminCheck } = await supabase
          .from("users")
          .select("is_admin")
          .eq("email", session.user.email)
          .single()

        if (!adminCheck?.is_admin) {
          router.push("/admin-login")
          return
        }
      }

      setCurrentUser(session.user)
    } catch (error) {
      console.error("Auth check error:", error)
      router.push("/admin-login")
    }
  }

  const fetchChanges = async () => {
    try {
      setLoading(true)
      setError("")

      let query = supabase
        .from("coinw_uid_changes")
        .select("*")
        .order("created_at", { ascending: false })

      if (statusFilter !== "all") {
        query = query.eq("status", statusFilter)
      }

      const { data: changesData, error: changesError } = await query

      if (changesError) throw changesError

      // ユーザー情報を取得
      if (changesData && changesData.length > 0) {
        const userIds = [...new Set(changesData.map(c => c.user_id))]
        const { data: usersData } = await supabase
          .from("users")
          .select("user_id, email")
          .in("user_id", userIds)

        const userMap = new Map(usersData?.map(u => [u.user_id, u.email]) || [])

        const enrichedData = changesData.map(c => ({
          ...c,
          email: userMap.get(c.user_id) || ""
        }))

        setChanges(enrichedData)
      } else {
        setChanges([])
      }
    } catch (err: any) {
      console.error("Fetch changes error:", err)
      setError("データの取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  const handleApprove = async (changeId: string) => {
    if (!confirm("このCoinW UID変更を承認しますか？\n\n承認すると、ユーザーのCoinW UIDが更新され、チャンネル紐付け確認済みになります。")) {
      return
    }

    try {
      setProcessing(changeId)
      setError("")

      const { data, error } = await supabase.rpc("approve_coinw_uid_change", {
        p_change_id: changeId,
        p_admin_email: currentUser?.email
      })

      if (error) throw error

      if (data && data[0]) {
        if (data[0].success) {
          alert(`承認完了: ${data[0].user_id}のCoinW UIDを「${data[0].new_coinw_uid}」に更新しました。`)
          fetchChanges()
        } else {
          throw new Error(data[0].message)
        }
      }
    } catch (err: any) {
      console.error("Approve error:", err)
      setError(`承認に失敗しました: ${err.message}`)
    } finally {
      setProcessing(null)
    }
  }

  const handleReject = async (changeId: string) => {
    if (!confirm("このCoinW UID変更申請を却下しますか？\n\n却下通知メールが送信されます。")) {
      return
    }

    const fixedReason = "CoinW UIDの紐付けが確認出来ませんでした"

    try {
      setProcessing(changeId)
      setError("")

      // 申請情報を取得（メール送信用）
      const changeData = changes.find(c => c.id === changeId)
      if (!changeData) {
        throw new Error("申請データが見つかりません")
      }

      const { data, error } = await supabase.rpc("reject_coinw_uid_change", {
        p_change_id: changeId,
        p_admin_email: currentUser?.email,
        p_reason: fixedReason
      })

      if (error) throw error

      if (data && data[0]) {
        if (data[0].success) {
          // 却下メールを送信
          if (changeData.email) {
            try {
              await supabase.functions.invoke("send-coinw-rejection-email", {
                body: {
                  to_email: changeData.email,
                  user_id: changeData.user_id,
                  old_coinw_uid: changeData.old_coinw_uid,
                  new_coinw_uid: changeData.new_coinw_uid,
                  rejection_reason: fixedReason
                }
              })
            } catch (emailErr) {
              console.error("Email sending failed:", emailErr)
              // メール送信失敗は致命的エラーではないので続行
            }
          }

          alert(`却下完了: ${data[0].user_id}のCoinW UID変更申請を却下しました。${changeData.email ? '\n却下通知メールを送信しました。' : ''}`)
          fetchChanges()
        } else {
          throw new Error(data[0].message)
        }
      }
    } catch (err: any) {
      console.error("Reject error:", err)
      setError(`却下に失敗しました: ${err.message}`)
    } finally {
      setProcessing(null)
    }
  }

  const filteredChanges = changes.filter(c =>
    c.user_id.toLowerCase().includes(searchTerm.toLowerCase()) ||
    c.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    c.new_coinw_uid.toLowerCase().includes(searchTerm.toLowerCase())
  )

  const pendingCount = changes.filter(c => c.status === "pending").length

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black flex items-center justify-center">
        <div className="flex items-center space-x-2 text-white">
          <Loader2 className="h-6 w-6 animate-spin" />
          <span>読み込み中...</span>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black">
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
                <h1 className="text-xl font-bold text-white">
                  CoinW UID変更承認
                  {pendingCount > 0 && (
                    <Badge className="ml-2 bg-yellow-600">{pendingCount}件待ち</Badge>
                  )}
                </h1>
                <p className="text-sm text-gray-400">ユーザーからのCoinW UID変更申請を承認・却下</p>
              </div>
            </div>
            <Button
              onClick={fetchChanges}
              variant="outline"
              size="sm"
              className="border-gray-600 text-gray-300 hover:bg-gray-700 bg-transparent"
            >
              <RefreshCw className="h-4 w-4 mr-2" />
              更新
            </Button>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-4 py-8">
        {error && (
          <Card className="mb-6 bg-red-900/20 border-red-500/50">
            <CardContent className="p-4 text-red-400">
              {error}
            </CardContent>
          </Card>
        )}

        {/* フィルター */}
        <Card className="mb-6 bg-gray-800 border-gray-700">
          <CardContent className="p-4">
            <div className="flex flex-wrap items-center gap-4">
              <div className="flex-1 min-w-[200px]">
                <div className="relative">
                  <Search className="h-4 w-4 absolute left-3 top-3 text-gray-400" />
                  <Input
                    placeholder="ユーザーID、メール、CoinW UIDで検索..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="pl-10 bg-gray-700 border-gray-600 text-white"
                  />
                </div>
              </div>
              <div>
                <select
                  value={statusFilter}
                  onChange={(e) => setStatusFilter(e.target.value as any)}
                  className="bg-gray-700 border border-gray-600 text-white rounded-md px-3 py-2 text-sm"
                >
                  <option value="pending">承認待ち</option>
                  <option value="approved">承認済み</option>
                  <option value="rejected">却下済み</option>
                  <option value="all">全て</option>
                </select>
              </div>
              <Badge variant="outline" className="text-gray-300">
                {filteredChanges.length}件
              </Badge>
            </div>
          </CardContent>
        </Card>

        {/* 申請一覧 */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white">変更申請一覧</CardTitle>
            <CardDescription className="text-gray-400">
              承認するとCoinW UIDが更新され、自動的にチャンネル紐付け確認済みになります
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {filteredChanges.map((change) => (
                <div key={change.id} className="border border-gray-600 rounded-lg p-4">
                  <div className="flex items-center justify-between">
                    <div className="flex-1">
                      <div className="flex items-center space-x-3 mb-2">
                        <Badge className="bg-blue-600">{change.user_id}</Badge>
                        {change.status === "pending" && (
                          <Badge className="bg-yellow-600">
                            <Clock className="h-3 w-3 mr-1" />
                            承認待ち
                          </Badge>
                        )}
                        {change.status === "approved" && (
                          <Badge className="bg-green-600">
                            <CheckCircle className="h-3 w-3 mr-1" />
                            承認済み
                          </Badge>
                        )}
                        {change.status === "rejected" && (
                          <Badge className="bg-red-600">
                            <XCircle className="h-3 w-3 mr-1" />
                            却下
                          </Badge>
                        )}
                      </div>

                      <div className="grid grid-cols-1 md:grid-cols-2 gap-2 text-sm">
                        <div>
                          <span className="text-gray-400">メール: </span>
                          <span className="text-white">{change.email}</span>
                        </div>
                        <div>
                          <span className="text-gray-400">申請日: </span>
                          <span className="text-white">
                            {new Date(change.created_at).toLocaleString('ja-JP')}
                          </span>
                        </div>
                        <div>
                          <span className="text-gray-400">変更前: </span>
                          <span className="text-gray-300">{change.old_coinw_uid || "(未設定)"}</span>
                        </div>
                        <div>
                          <span className="text-gray-400">変更後: </span>
                          <span className="text-cyan-400 font-semibold">{change.new_coinw_uid}</span>
                        </div>
                        {change.reviewed_at && (
                          <div>
                            <span className="text-gray-400">処理日: </span>
                            <span className="text-white">
                              {new Date(change.reviewed_at).toLocaleString('ja-JP')}
                            </span>
                          </div>
                        )}
                        {change.reviewed_by && (
                          <div>
                            <span className="text-gray-400">処理者: </span>
                            <span className="text-white">{change.reviewed_by}</span>
                          </div>
                        )}
                        {change.rejection_reason && (
                          <div className="col-span-2">
                            <span className="text-gray-400">却下理由: </span>
                            <span className="text-red-400">{change.rejection_reason}</span>
                          </div>
                        )}
                      </div>
                    </div>

                    {change.status === "pending" && (
                      <div className="flex items-center space-x-2 ml-4">
                        <Button
                          onClick={() => handleApprove(change.id)}
                          disabled={processing === change.id}
                          className="bg-green-600 hover:bg-green-700"
                        >
                          {processing === change.id ? (
                            <Loader2 className="h-4 w-4 animate-spin" />
                          ) : (
                            <>
                              <CheckCircle className="h-4 w-4 mr-1" />
                              承認
                            </>
                          )}
                        </Button>
                        <Button
                          onClick={() => handleReject(change.id)}
                          disabled={processing === change.id}
                          variant="outline"
                          className="border-red-600 text-red-400 hover:bg-red-900 bg-transparent"
                        >
                          <XCircle className="h-4 w-4 mr-1" />
                          却下
                        </Button>
                      </div>
                    )}
                  </div>
                </div>
              ))}

              {filteredChanges.length === 0 && (
                <div className="text-center py-8 text-gray-400">
                  {statusFilter === "pending" ? (
                    <>
                      <CheckCircle className="h-16 w-16 mx-auto mb-4 opacity-50" />
                      <p className="text-xl mb-2">承認待ちの申請はありません</p>
                    </>
                  ) : (
                    <>
                      <Clock className="h-16 w-16 mx-auto mb-4 opacity-50" />
                      <p className="text-xl mb-2">該当する申請がありません</p>
                    </>
                  )}
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
