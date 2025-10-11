"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Badge } from "@/components/ui/badge"
import { Mail, Send, History, Users, User, RefreshCw, Shield, Eye } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface EmailHistory {
  email_id: string
  subject: string
  email_type: string
  target_group: string | null
  created_at: string
  total_recipients: number
  sent_count: number
  failed_count: number
  read_count: number
}

interface UserSearchResult {
  user_id: string
  email: string
  full_name: string
}

export default function AdminEmailsPage() {
  const [currentUser, setCurrentUser] = useState<any>(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [loading, setLoading] = useState(true)
  const [actionLoading, setActionLoading] = useState(false)
  const router = useRouter()

  // 一斉メール送信フォーム
  const [subject, setSubject] = useState("")
  const [body, setBody] = useState("")
  const [targetGroup, setTargetGroup] = useState("all")

  // 個別メール送信フォーム
  const [individualSubject, setIndividualSubject] = useState("")
  const [individualBody, setIndividualBody] = useState("")
  const [targetUserIds, setTargetUserIds] = useState("")

  // ユーザー検索機能
  const [userSearchQuery, setUserSearchQuery] = useState("")
  const [userSearchResults, setUserSearchResults] = useState<UserSearchResult[]>([])
  const [selectedUsers, setSelectedUsers] = useState<UserSearchResult[]>([])
  const [showSearchResults, setShowSearchResults] = useState(false)

  // メール送信履歴
  const [emailHistory, setEmailHistory] = useState<EmailHistory[]>([])

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

      // 管理者権限チェック
      if (user.email === "basarasystems@gmail.com" || user.email === "support@dshsupport.biz") {
        setIsAdmin(true)
        fetchEmailHistory(user.email)
        setLoading(false)
        return
      }

      const { data: userData } = await supabase
        .from("users")
        .select("is_admin")
        .eq("email", user.email)
        .single()

      if (!userData?.is_admin) {
        alert("管理者権限がありません")
        router.push("/dashboard")
        return
      }

      setIsAdmin(true)
      fetchEmailHistory(user.email)
    } catch (error) {
      console.error("Admin access check error:", error)
      alert("管理者権限の確認でエラーが発生しました")
    } finally {
      setLoading(false)
    }
  }

  const fetchEmailHistory = async (adminEmail: string) => {
    try {
      const { data, error } = await supabase.rpc("get_email_history", {
        p_admin_email: adminEmail,
        p_limit: 50,
      })

      if (error) throw error
      setEmailHistory(data || [])
    } catch (error: any) {
      console.error("Error fetching email history:", error)
    }
  }

  const sendBroadcastEmail = async () => {
    if (!subject.trim() || !body.trim()) {
      alert("件名と本文を入力してください")
      return
    }

    if (!confirm(`${targetGroup === "all" ? "全ユーザー" : targetGroup === "approved" ? "承認済みユーザー" : "未承認ユーザー"}にメールを送信しますか？`)) {
      return
    }

    setActionLoading(true)
    try {
      // メール作成
      const { data: createResult, error: createError } = await supabase.rpc("create_system_email", {
        p_subject: subject,
        p_body: body,
        p_email_type: "broadcast",
        p_admin_email: currentUser.email,
        p_target_group: targetGroup,
      })

      if (createError) throw createError

      const emailId = createResult.email_id

      // メール送信（Edge Function呼び出し）
      const { data: sendResult, error: sendError } = await supabase.functions.invoke("send-system-email", {
        body: { email_id: emailId },
      })

      if (sendError) throw sendError

      alert(`メール送信完了\n${sendResult.sent_count}件送信成功、${sendResult.failed_count}件失敗`)

      // フォームクリア
      setSubject("")
      setBody("")

      // 履歴更新
      fetchEmailHistory(currentUser.email)
    } catch (error: any) {
      console.error("Email send error:", error)
      alert(`メール送信エラー: ${error.message}`)
    } finally {
      setActionLoading(false)
    }
  }

  // ユーザー検索
  const searchUsers = async (query: string) => {
    if (!query || query.length < 2) {
      setUserSearchResults([])
      return
    }

    try {
      const { data, error } = await supabase
        .from("users")
        .select("user_id, email, full_name")
        .or(`user_id.ilike.%${query}%,email.ilike.%${query}%,full_name.ilike.%${query}%`)
        .limit(10)

      if (error) throw error
      setUserSearchResults(data || [])
      setShowSearchResults(true)
    } catch (error: any) {
      console.error("User search error:", error)
    }
  }

  // ユーザー追加
  const addSelectedUser = (user: UserSearchResult) => {
    if (!selectedUsers.find(u => u.user_id === user.user_id)) {
      setSelectedUsers([...selectedUsers, user])
    }
    setUserSearchQuery("")
    setUserSearchResults([])
    setShowSearchResults(false)
  }

  // ユーザー削除
  const removeSelectedUser = (userId: string) => {
    setSelectedUsers(selectedUsers.filter(u => u.user_id !== userId))
  }

  const sendIndividualEmail = async () => {
    if (!individualSubject.trim() || !individualBody.trim()) {
      alert("件名、本文を入力してください")
      return
    }

    if (selectedUsers.length === 0) {
      alert("送信先ユーザーを選択してください")
      return
    }

    const userIdArray = selectedUsers.map(u => u.user_id)

    if (!confirm(`${userIdArray.length}名のユーザーにメールを送信しますか？`)) {
      return
    }

    setActionLoading(true)
    try {
      // メール作成
      const { data: createResult, error: createError } = await supabase.rpc("create_system_email", {
        p_subject: individualSubject,
        p_body: individualBody,
        p_email_type: "individual",
        p_admin_email: currentUser.email,
        p_target_user_ids: userIdArray,
      })

      if (createError) throw createError

      const emailId = createResult.email_id

      // メール送信（Edge Function呼び出し）
      const { data: sendResult, error: sendError } = await supabase.functions.invoke("send-system-email", {
        body: { email_id: emailId },
      })

      if (sendError) throw sendError

      alert(`メール送信完了\n${sendResult.sent_count}件送信成功、${sendResult.failed_count}件失敗`)

      // フォームクリア
      setIndividualSubject("")
      setIndividualBody("")
      setSelectedUsers([])

      // 履歴更新
      fetchEmailHistory(currentUser.email)
    } catch (error: any) {
      console.error("Email send error:", error)
      alert(`メール送信エラー: ${error.message}`)
    } finally {
      setActionLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-white">読み込み中...</p>
        </div>
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
            <Button onClick={() => router.push("/dashboard")} className="mt-4 w-full">
              ダッシュボードに戻る
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-900 p-4">
      <div className="max-w-6xl mx-auto">
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="text-white flex items-center">
                <Mail className="w-5 h-5 mr-2" />
                システムメール送信 - {currentUser?.email}
              </CardTitle>
              <Button
                onClick={() => router.push("/admin")}
                variant="outline"
                size="sm"
                className="bg-blue-600 hover:bg-blue-700 text-white border-blue-600"
              >
                管理者ダッシュボード
              </Button>
            </div>
          </CardHeader>
          <CardContent>
            <Tabs defaultValue="broadcast" className="w-full">
              <TabsList className="grid w-full grid-cols-3 bg-gray-700">
                <TabsTrigger value="broadcast" className="data-[state=active]:bg-blue-600">
                  <Users className="w-4 h-4 mr-2" />
                  一斉送信
                </TabsTrigger>
                <TabsTrigger value="individual" className="data-[state=active]:bg-green-600">
                  <User className="w-4 h-4 mr-2" />
                  個別送信
                </TabsTrigger>
                <TabsTrigger value="history" className="data-[state=active]:bg-purple-600">
                  <History className="w-4 h-4 mr-2" />
                  送信履歴
                </TabsTrigger>
              </TabsList>

              {/* 一斉送信タブ */}
              <TabsContent value="broadcast" className="space-y-4 mt-4">
                <div className="space-y-4">
                  <div>
                    <Label className="text-white">送信先グループ</Label>
                    <Select value={targetGroup} onValueChange={setTargetGroup}>
                      <SelectTrigger className="bg-gray-700 border-gray-600 text-white">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent className="bg-gray-700 border-gray-600">
                        <SelectItem value="all">全ユーザー</SelectItem>
                        <SelectItem value="approved">承認済みユーザーのみ</SelectItem>
                        <SelectItem value="unapproved">未承認ユーザーのみ</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>

                  <div>
                    <Label className="text-white">件名</Label>
                    <Input
                      value={subject}
                      onChange={(e) => setSubject(e.target.value)}
                      placeholder="メールの件名を入力"
                      className="bg-gray-700 border-gray-600 text-white"
                    />
                  </div>

                  <div>
                    <Label className="text-white">本文（HTML可）</Label>
                    <Textarea
                      value={body}
                      onChange={(e) => setBody(e.target.value)}
                      placeholder="メール本文を入力（HTMLタグ使用可）"
                      className="bg-gray-700 border-gray-600 text-white min-h-[300px]"
                      rows={12}
                    />
                  </div>

                  <Button
                    onClick={sendBroadcastEmail}
                    disabled={actionLoading}
                    className="w-full bg-blue-600 hover:bg-blue-700"
                    size="lg"
                  >
                    <Send className="w-4 h-4 mr-2" />
                    {actionLoading ? "送信中..." : "一斉送信"}
                  </Button>
                </div>
              </TabsContent>

              {/* 個別送信タブ */}
              <TabsContent value="individual" className="space-y-4 mt-4">
                <div className="space-y-4">
                  <div className="relative">
                    <Label className="text-white">送信先ユーザー検索</Label>
                    <Input
                      value={userSearchQuery}
                      onChange={(e) => {
                        setUserSearchQuery(e.target.value)
                        searchUsers(e.target.value)
                      }}
                      onFocus={() => userSearchResults.length > 0 && setShowSearchResults(true)}
                      placeholder="ユーザーID、メールアドレス、名前で検索"
                      className="bg-gray-700 border-gray-600 text-white"
                    />

                    {/* 検索結果ドロップダウン */}
                    {showSearchResults && userSearchResults.length > 0 && (
                      <div className="absolute z-10 w-full mt-1 bg-gray-700 border border-gray-600 rounded-lg shadow-lg max-h-60 overflow-y-auto">
                        {userSearchResults.map((user) => (
                          <div
                            key={user.user_id}
                            onClick={() => addSelectedUser(user)}
                            className="p-3 hover:bg-gray-600 cursor-pointer border-b border-gray-600 last:border-b-0"
                          >
                            <div className="text-white font-medium">{user.full_name}</div>
                            <div className="text-sm text-gray-400">{user.email}</div>
                            <div className="text-xs text-gray-500">ID: {user.user_id}</div>
                          </div>
                        ))}
                      </div>
                    )}

                    {/* 選択済みユーザー一覧 */}
                    {selectedUsers.length > 0 && (
                      <div className="mt-3 space-y-2">
                        <Label className="text-white text-sm">選択済みユーザー（{selectedUsers.length}名）</Label>
                        <div className="flex flex-wrap gap-2">
                          {selectedUsers.map((user) => (
                            <Badge
                              key={user.user_id}
                              className="bg-blue-600 text-white px-3 py-1 flex items-center gap-2"
                            >
                              <span>{user.full_name} ({user.user_id})</span>
                              <button
                                onClick={() => removeSelectedUser(user.user_id)}
                                className="text-white hover:text-red-300"
                              >
                                ✕
                              </button>
                            </Badge>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>

                  <div>
                    <Label className="text-white">件名</Label>
                    <Input
                      value={individualSubject}
                      onChange={(e) => setIndividualSubject(e.target.value)}
                      placeholder="メールの件名を入力"
                      className="bg-gray-700 border-gray-600 text-white"
                    />
                  </div>

                  <div>
                    <Label className="text-white">本文（HTML可）</Label>
                    <Textarea
                      value={individualBody}
                      onChange={(e) => setIndividualBody(e.target.value)}
                      placeholder="メール本文を入力（HTMLタグ使用可）"
                      className="bg-gray-700 border-gray-600 text-white min-h-[300px]"
                      rows={12}
                    />
                  </div>

                  <Button
                    onClick={sendIndividualEmail}
                    disabled={actionLoading}
                    className="w-full bg-green-600 hover:bg-green-700"
                    size="lg"
                  >
                    <Send className="w-4 h-4 mr-2" />
                    {actionLoading ? "送信中..." : "個別送信"}
                  </Button>
                </div>
              </TabsContent>

              {/* 送信履歴タブ */}
              <TabsContent value="history" className="mt-4">
                <div className="space-y-4">
                  <div className="flex justify-between items-center">
                    <h3 className="text-white text-lg font-semibold">メール送信履歴</h3>
                    <Button
                      onClick={() => fetchEmailHistory(currentUser.email)}
                      size="sm"
                      variant="outline"
                      className="bg-gray-700 text-white border-gray-600"
                    >
                      <RefreshCw className="w-4 h-4 mr-2" />
                      更新
                    </Button>
                  </div>

                  {emailHistory.length === 0 ? (
                    <div className="text-center py-8 text-gray-400">
                      送信履歴がありません
                    </div>
                  ) : (
                    <div className="space-y-3">
                      {emailHistory.map((email) => (
                        <Card key={email.email_id} className="bg-gray-700 border-gray-600">
                          <CardContent className="p-4">
                            <div className="flex justify-between items-start">
                              <div className="flex-1">
                                <h4 className="text-white font-semibold">{email.subject}</h4>
                                <div className="flex items-center space-x-2 mt-2">
                                  {email.email_type === "broadcast" ? (
                                    <Badge className="bg-blue-600">
                                      <Users className="w-3 h-3 mr-1" />
                                      一斉送信
                                    </Badge>
                                  ) : (
                                    <Badge className="bg-green-600">
                                      <User className="w-3 h-3 mr-1" />
                                      個別送信
                                    </Badge>
                                  )}
                                  {email.target_group && (
                                    <Badge variant="outline" className="text-gray-300">
                                      {email.target_group === "all"
                                        ? "全ユーザー"
                                        : email.target_group === "approved"
                                        ? "承認済み"
                                        : "未承認"}
                                    </Badge>
                                  )}
                                </div>
                                <p className="text-sm text-gray-400 mt-2">
                                  送信日時: {new Date(email.created_at).toLocaleString("ja-JP")}
                                </p>
                              </div>
                              <div className="text-right">
                                <div className="text-sm text-gray-300">
                                  <span className="text-white font-semibold">{email.total_recipients}</span> 件
                                </div>
                                <div className="text-xs text-gray-400 mt-1">
                                  送信: {email.sent_count} / 失敗: {email.failed_count} / 既読: {email.read_count}
                                </div>
                              </div>
                            </div>
                          </CardContent>
                        </Card>
                      ))}
                    </div>
                  )}
                </div>
              </TabsContent>
            </Tabs>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
