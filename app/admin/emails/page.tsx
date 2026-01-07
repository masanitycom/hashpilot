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
import { Mail, Send, History, Users, User, RefreshCw, Shield, Eye, Info, RotateCcw, Inbox, Trash2 } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { AVAILABLE_TEMPLATE_VARIABLES } from "@/lib/email-template"

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
  pending_count: number
}

interface UserSearchResult {
  user_id: string
  email: string
  full_name: string
}

interface ReceivedEmail {
  id: string
  message_id: string
  from_email: string
  from_name: string
  to_email: string
  subject: string
  body_text: string
  body_html: string
  received_at: string
  is_read: boolean
  is_replied: boolean
  replied_at: string | null
}

export default function AdminEmailsPage() {
  const [currentUser, setCurrentUser] = useState<any>(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [loading, setLoading] = useState(true)
  const [actionLoading, setActionLoading] = useState(false)
  const [resendingEmailId, setResendingEmailId] = useState<string | null>(null)
  const router = useRouter()

  // 送信元アドレス選択
  const [senderAddress, setSenderAddress] = useState("noreply@send.hashpilot.biz")
  const SENDER_OPTIONS = [
    { value: "noreply@send.hashpilot.biz", label: "noreply@send.hashpilot.biz（システム通知用）" },
    { value: "support@hashpilot.biz", label: "support@hashpilot.biz（サポート用・返信可）" },
  ]

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

  // 受信メール
  const [receivedEmails, setReceivedEmails] = useState<ReceivedEmail[]>([])
  const [selectedReceivedEmail, setSelectedReceivedEmail] = useState<ReceivedEmail | null>(null)
  const [inboxLoading, setInboxLoading] = useState(false)
  const [showUnreadOnly, setShowUnreadOnly] = useState(false)

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

  // 受信メール取得
  const fetchReceivedEmails = async () => {
    setInboxLoading(true)
    try {
      const { data, error } = await supabase.rpc("get_received_emails", {
        p_limit: 50,
        p_offset: 0,
        p_unread_only: showUnreadOnly,
      })

      if (error) throw error
      setReceivedEmails(data || [])
    } catch (error: any) {
      console.error("Error fetching received emails:", error)
    } finally {
      setInboxLoading(false)
    }
  }

  // 受信メールを既読にする
  const markAsRead = async (emailId: string) => {
    try {
      const { error } = await supabase.rpc("mark_received_email_as_read", {
        p_email_id: emailId,
      })
      if (error) throw error

      // ローカルステートを更新
      setReceivedEmails(prev =>
        prev.map(e => e.id === emailId ? { ...e, is_read: true } : e)
      )
    } catch (error: any) {
      console.error("Error marking email as read:", error)
    }
  }

  // メール詳細を開く
  const openEmailDetail = async (email: ReceivedEmail) => {
    setSelectedReceivedEmail(email)
    if (!email.is_read) {
      await markAsRead(email.id)
    }
  }

  // 受信メールを削除
  const deleteReceivedEmail = async (emailId: string) => {
    if (!confirm("このメールを削除しますか？")) return

    try {
      const { error } = await supabase
        .from("received_emails")
        .delete()
        .eq("id", emailId)

      if (error) throw error

      // ローカルステートを更新
      setReceivedEmails(prev => prev.filter(e => e.id !== emailId))
      setSelectedReceivedEmail(null)
      alert("メールを削除しました")
    } catch (error: any) {
      console.error("Error deleting email:", error)
      alert("削除に失敗しました: " + error.message)
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
      // メール作成（SQL関数内で自動的にHTMLに変換される）
      const { data: createResult, error: createError } = await supabase.rpc("create_system_email", {
        p_subject: subject,
        p_body: body,
        p_email_type: "broadcast",
        p_admin_email: currentUser.email,
        p_target_group: targetGroup,
        p_from_email: senderAddress,
      })

      if (createError) throw createError

      const emailId = createResult.email_id
      const totalRecipients = createResult.recipient_count || 0

      // バッチ処理でメール送信（50件ずつ）
      const BATCH_SIZE = 50
      let totalSent = 0
      let totalFailed = 0
      let batchNumber = 1
      const totalBatches = Math.ceil(totalRecipients / BATCH_SIZE)

      while (true) {
        console.log(`バッチ ${batchNumber}/${totalBatches} 送信中...`)

        const { data: sendResult, error: sendError } = await supabase.functions.invoke("send-system-email", {
          body: { email_id: emailId, batch_size: BATCH_SIZE },
        })

        if (sendError) {
          console.error(`バッチ ${batchNumber} エラー:`, sendError)
          // エラーでも続行（次のバッチを試す）
          break
        }

        totalSent += sendResult.sent_count || 0
        totalFailed += sendResult.failed_count || 0

        // 送信するものがなくなったら終了
        if (sendResult.sent_count === 0 && sendResult.failed_count === 0) {
          break
        }

        batchNumber++

        // 次のバッチまで少し待機（レート制限対策）
        if (sendResult.sent_count > 0) {
          await new Promise(resolve => setTimeout(resolve, 1000))
        }
      }

      alert(`メール送信完了\n${totalSent}件送信成功、${totalFailed}件失敗`)

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
      // メール作成（SQL関数内で自動的にHTMLに変換される）
      const { data: createResult, error: createError } = await supabase.rpc("create_system_email", {
        p_subject: individualSubject,
        p_body: individualBody,
        p_email_type: "individual",
        p_admin_email: currentUser.email,
        p_target_user_ids: userIdArray,
        p_from_email: senderAddress,
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

  // 未送信メールの再送信
  const resendPendingEmails = async (emailId: string, pendingCount: number) => {
    if (!confirm(`このメールの未送信${pendingCount}件を再送信しますか？\n\n※50件ずつ送信されます`)) {
      return
    }

    setResendingEmailId(emailId)
    try {
      const BATCH_SIZE = 50
      let totalSent = 0
      let totalFailed = 0
      let batchNumber = 1
      const totalBatches = Math.ceil(pendingCount / BATCH_SIZE)

      while (true) {
        console.log(`再送信バッチ ${batchNumber}/${totalBatches} 送信中...`)

        const { data: sendResult, error: sendError } = await supabase.functions.invoke("send-system-email", {
          body: { email_id: emailId, batch_size: BATCH_SIZE },
        })

        if (sendError) {
          console.error(`バッチ ${batchNumber} エラー:`, sendError)
          break
        }

        totalSent += sendResult.sent_count || 0
        totalFailed += sendResult.failed_count || 0

        if (sendResult.sent_count === 0 && sendResult.failed_count === 0) {
          break
        }

        batchNumber++

        if (sendResult.sent_count > 0) {
          await new Promise(resolve => setTimeout(resolve, 1000))
        }
      }

      alert(`再送信完了\n${totalSent}件送信成功、${totalFailed}件失敗`)
      fetchEmailHistory(currentUser.email)
    } catch (error: any) {
      console.error("Resend error:", error)
      alert(`再送信エラー: ${error.message}`)
    } finally {
      setResendingEmailId(null)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-white">読み込み中...</p>
        </div>
      </div>
    )
  }

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
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
    <div className="min-h-screen bg-black p-4">
      <div className="max-w-6xl mx-auto space-y-4">
        {/* ヘッダー */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <img src="/images/hash-pilot-logo.png" alt="HASH PILOT" className="h-10 rounded-lg shadow-lg" />
            <h1 className="text-2xl font-bold text-white flex items-center gap-2">
              <Mail className="h-6 w-6 text-blue-400" />
              システムメール送信
            </h1>
          </div>
          <div className="flex items-center gap-2">
            <Badge className="bg-blue-600 text-white text-sm">{currentUser?.email}</Badge>
            <Button
              onClick={() => router.push("/admin")}
              variant="outline"
              size="sm"
              className="bg-blue-600 hover:bg-blue-700 text-white border-blue-600"
            >
              管理者ダッシュボード
            </Button>
          </div>
        </div>

        <Card className="bg-gray-800 border-gray-700">
          <CardContent className="pt-6">
            <Tabs defaultValue="broadcast" className="w-full">
              <TabsList className="grid w-full grid-cols-4 bg-gray-700">
                <TabsTrigger value="broadcast" className="data-[state=active]:bg-blue-600">
                  <Users className="w-4 h-4 mr-2" />
                  一斉送信
                </TabsTrigger>
                <TabsTrigger value="individual" className="data-[state=active]:bg-green-600">
                  <User className="w-4 h-4 mr-2" />
                  個別送信
                </TabsTrigger>
                <TabsTrigger value="inbox" className="data-[state=active]:bg-orange-600" onClick={fetchReceivedEmails}>
                  <Inbox className="w-4 h-4 mr-2" />
                  受信箱
                  {receivedEmails.filter(e => !e.is_read).length > 0 && (
                    <Badge className="ml-1 bg-red-500 text-white text-xs px-1.5">
                      {receivedEmails.filter(e => !e.is_read).length}
                    </Badge>
                  )}
                </TabsTrigger>
                <TabsTrigger value="history" className="data-[state=active]:bg-purple-600">
                  <History className="w-4 h-4 mr-2" />
                  送信履歴
                </TabsTrigger>
              </TabsList>

              {/* 一斉送信タブ */}
              <TabsContent value="broadcast" className="space-y-4 mt-4">
                <div className="space-y-4">
                  {/* 送信元アドレス選択（目立つボタン形式） */}
                  <div className="p-4 bg-gray-900 rounded-lg border-2 border-gray-600">
                    <Label className="text-white text-lg font-bold mb-3 block">送信元アドレス</Label>
                    <div className="grid grid-cols-2 gap-3">
                      <button
                        type="button"
                        onClick={() => setSenderAddress("noreply@send.hashpilot.biz")}
                        className={`p-4 rounded-lg border-2 transition-all ${
                          senderAddress === "noreply@send.hashpilot.biz"
                            ? "bg-blue-600 border-blue-400 ring-2 ring-blue-400"
                            : "bg-gray-700 border-gray-600 hover:border-gray-500"
                        }`}
                      >
                        <div className="flex items-center justify-center gap-2 mb-2">
                          {senderAddress === "noreply@send.hashpilot.biz" && (
                            <span className="text-white text-xl">✓</span>
                          )}
                          <span className="text-white font-bold">システム通知用</span>
                        </div>
                        <p className="text-sm text-gray-300">noreply@send.hashpilot.biz</p>
                        <p className="text-xs text-gray-400 mt-1">返信不可</p>
                      </button>
                      <button
                        type="button"
                        onClick={() => setSenderAddress("support@hashpilot.biz")}
                        className={`p-4 rounded-lg border-2 transition-all ${
                          senderAddress === "support@hashpilot.biz"
                            ? "bg-green-600 border-green-400 ring-2 ring-green-400"
                            : "bg-gray-700 border-gray-600 hover:border-gray-500"
                        }`}
                      >
                        <div className="flex items-center justify-center gap-2 mb-2">
                          {senderAddress === "support@hashpilot.biz" && (
                            <span className="text-white text-xl">✓</span>
                          )}
                          <span className="text-white font-bold">サポート用</span>
                        </div>
                        <p className="text-sm text-gray-300">support@hashpilot.biz</p>
                        <p className="text-xs text-green-300 mt-1">返信可能</p>
                      </button>
                    </div>
                  </div>

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

                    {/* テンプレート変数ヘルプ */}
                    <div className="mb-3 p-3 bg-blue-900/30 border border-blue-600 rounded-lg">
                      <div className="flex items-start space-x-2">
                        <Info className="w-4 h-4 text-blue-400 mt-0.5 flex-shrink-0" />
                        <div className="text-sm">
                          <p className="text-blue-300 font-semibold mb-1">利用可能な変数</p>
                          <div className="text-blue-200 space-y-1">
                            {AVAILABLE_TEMPLATE_VARIABLES.map((v) => (
                              <div key={v.key} className="flex items-center space-x-2">
                                <code className="bg-blue-800/50 px-2 py-0.5 rounded text-xs">{v.key}</code>
                                <span className="text-xs">→ {v.description}</span>
                              </div>
                            ))}
                          </div>
                          <p className="text-blue-300 text-xs mt-2">
                            ※ 各ユーザーの情報が自動で置き換わります
                          </p>
                        </div>
                      </div>
                    </div>

                    <Textarea
                      value={body}
                      onChange={(e) => setBody(e.target.value)}
                      placeholder={`例:
ユーザーID {{user_id}} 様

いつもHASH PILOT NFTをご利用いただきありがとうございます。

【ここに本文を入力】

ご不明な点がございましたら、お気軽にお問い合わせください。

※ {{user_id}}, {{email}} が自動で置換されます`}
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
                  {/* 送信元アドレス選択（目立つボタン形式） */}
                  <div className="p-4 bg-gray-900 rounded-lg border-2 border-gray-600">
                    <Label className="text-white text-lg font-bold mb-3 block">送信元アドレス</Label>
                    <div className="grid grid-cols-2 gap-3">
                      <button
                        type="button"
                        onClick={() => setSenderAddress("noreply@send.hashpilot.biz")}
                        className={`p-4 rounded-lg border-2 transition-all ${
                          senderAddress === "noreply@send.hashpilot.biz"
                            ? "bg-blue-600 border-blue-400 ring-2 ring-blue-400"
                            : "bg-gray-700 border-gray-600 hover:border-gray-500"
                        }`}
                      >
                        <div className="flex items-center justify-center gap-2 mb-2">
                          {senderAddress === "noreply@send.hashpilot.biz" && (
                            <span className="text-white text-xl">✓</span>
                          )}
                          <span className="text-white font-bold">システム通知用</span>
                        </div>
                        <p className="text-sm text-gray-300">noreply@send.hashpilot.biz</p>
                        <p className="text-xs text-gray-400 mt-1">返信不可</p>
                      </button>
                      <button
                        type="button"
                        onClick={() => setSenderAddress("support@hashpilot.biz")}
                        className={`p-4 rounded-lg border-2 transition-all ${
                          senderAddress === "support@hashpilot.biz"
                            ? "bg-green-600 border-green-400 ring-2 ring-green-400"
                            : "bg-gray-700 border-gray-600 hover:border-gray-500"
                        }`}
                      >
                        <div className="flex items-center justify-center gap-2 mb-2">
                          {senderAddress === "support@hashpilot.biz" && (
                            <span className="text-white text-xl">✓</span>
                          )}
                          <span className="text-white font-bold">サポート用</span>
                        </div>
                        <p className="text-sm text-gray-300">support@hashpilot.biz</p>
                        <p className="text-xs text-green-300 mt-1">返信可能</p>
                      </button>
                    </div>
                  </div>

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

                    {/* テンプレート変数ヘルプ */}
                    <div className="mb-3 p-3 bg-blue-900/30 border border-blue-600 rounded-lg">
                      <div className="flex items-start space-x-2">
                        <Info className="w-4 h-4 text-blue-400 mt-0.5 flex-shrink-0" />
                        <div className="text-sm">
                          <p className="text-blue-300 font-semibold mb-1">利用可能な変数</p>
                          <div className="text-blue-200 space-y-1">
                            {AVAILABLE_TEMPLATE_VARIABLES.map((v) => (
                              <div key={v.key} className="flex items-center space-x-2">
                                <code className="bg-blue-800/50 px-2 py-0.5 rounded text-xs">{v.key}</code>
                                <span className="text-xs">→ {v.description}</span>
                              </div>
                            ))}
                          </div>
                          <p className="text-blue-300 text-xs mt-2">
                            ※ 各ユーザーの情報が自動で置き換わります
                          </p>
                        </div>
                      </div>
                    </div>

                    <Textarea
                      value={individualBody}
                      onChange={(e) => setIndividualBody(e.target.value)}
                      placeholder={`例:
ユーザーID {{user_id}} 様

いつもHASH PILOT NFTをご利用いただきありがとうございます。

【ここに本文を入力】

ご不明な点がございましたら、お気軽にお問い合わせください。

※ {{user_id}}, {{email}} が自動で置換されます`}
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

              {/* 受信箱タブ */}
              <TabsContent value="inbox" className="mt-4">
                <div className="space-y-4">
                  <div className="flex justify-between items-center">
                    <h3 className="text-white text-lg font-semibold flex items-center gap-2">
                      <Inbox className="w-5 h-5 text-orange-400" />
                      受信メール
                    </h3>
                    <div className="flex items-center gap-2">
                      <label className="flex items-center gap-2 text-sm text-gray-300">
                        <input
                          type="checkbox"
                          checked={showUnreadOnly}
                          onChange={(e) => setShowUnreadOnly(e.target.checked)}
                          className="rounded"
                        />
                        未読のみ
                      </label>
                      <Button
                        onClick={fetchReceivedEmails}
                        size="sm"
                        variant="outline"
                        className="bg-gray-700 text-white border-gray-600"
                        disabled={inboxLoading}
                      >
                        <RefreshCw className={`w-4 h-4 mr-2 ${inboxLoading ? "animate-spin" : ""}`} />
                        更新
                      </Button>
                    </div>
                  </div>

                  {inboxLoading ? (
                    <div className="text-center py-8">
                      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-orange-500 mx-auto"></div>
                      <p className="mt-2 text-gray-400">読み込み中...</p>
                    </div>
                  ) : receivedEmails.length === 0 ? (
                    <div className="text-center py-8 text-gray-400">
                      <Inbox className="w-12 h-12 mx-auto mb-2 opacity-50" />
                      受信メールがありません
                    </div>
                  ) : (
                    <div className="space-y-2">
                      {receivedEmails.map((email) => (
                        <Card
                          key={email.id}
                          onClick={() => openEmailDetail(email)}
                          className={`cursor-pointer transition-colors ${
                            email.is_read
                              ? "bg-gray-700 border-gray-600 hover:bg-gray-650"
                              : "bg-orange-900/30 border-orange-600 hover:bg-orange-900/50"
                          }`}
                        >
                          <CardContent className="p-4">
                            <div className="flex justify-between items-start">
                              <div className="flex-1 min-w-0">
                                <div className="flex items-center gap-2">
                                  {!email.is_read && (
                                    <span className="w-2 h-2 bg-orange-500 rounded-full flex-shrink-0"></span>
                                  )}
                                  <span className="text-white font-semibold truncate">
                                    {email.from_name || email.from_email}
                                  </span>
                                </div>
                                <p className="text-sm text-gray-400 truncate mt-1">
                                  {email.from_email}
                                </p>
                                <p className="text-white mt-2 truncate">{email.subject || "(件名なし)"}</p>
                                <p className="text-sm text-gray-400 mt-1 line-clamp-2">
                                  {email.body_text?.substring(0, 100) || ""}
                                </p>
                              </div>
                              <div className="text-right flex-shrink-0 ml-4">
                                <p className="text-xs text-gray-400">
                                  {new Date(email.received_at).toLocaleString("ja-JP")}
                                </p>
                                <div className="flex gap-1 mt-2 justify-end">
                                  {email.is_replied && (
                                    <Badge className="bg-green-600 text-xs">返信済み</Badge>
                                  )}
                                  <Badge className="bg-gray-600 text-xs">{email.to_email}</Badge>
                                </div>
                              </div>
                            </div>
                          </CardContent>
                        </Card>
                      ))}
                    </div>
                  )}
                </div>

                {/* メール詳細モーダル */}
                {selectedReceivedEmail && (
                  <div className="fixed inset-0 bg-black/90 flex items-center justify-center z-50 p-4">
                    <Card className="bg-gray-900 border-gray-600 w-full max-w-4xl max-h-[90vh] overflow-hidden flex flex-col shadow-2xl">
                      {/* ヘッダー */}
                      <div className="bg-gray-800 border-b border-gray-600 p-6 flex-shrink-0">
                        <div className="flex justify-between items-start">
                          <div className="flex-1">
                            <h2 className="text-xl font-bold text-white mb-4">
                              {selectedReceivedEmail.subject || "(件名なし)"}
                            </h2>
                            <div className="space-y-2">
                              <div className="flex items-center gap-3">
                                <span className="text-gray-400 w-16">From:</span>
                                <span className="text-white font-medium">
                                  {selectedReceivedEmail.from_name || selectedReceivedEmail.from_email}
                                </span>
                                <span className="text-gray-500 text-sm">
                                  &lt;{selectedReceivedEmail.from_email}&gt;
                                </span>
                              </div>
                              <div className="flex items-center gap-3">
                                <span className="text-gray-400 w-16">To:</span>
                                <span className="text-orange-400 font-medium">{selectedReceivedEmail.to_email}</span>
                              </div>
                              <div className="flex items-center gap-3">
                                <span className="text-gray-400 w-16">Date:</span>
                                <span className="text-gray-300">
                                  {new Date(selectedReceivedEmail.received_at).toLocaleString("ja-JP")}
                                </span>
                              </div>
                            </div>
                          </div>
                          <Button
                            onClick={() => setSelectedReceivedEmail(null)}
                            size="lg"
                            variant="ghost"
                            className="text-gray-400 hover:text-white hover:bg-gray-700 text-2xl px-3"
                          >
                            ✕
                          </Button>
                        </div>
                      </div>

                      {/* 本文 */}
                      <div className="flex-1 overflow-auto p-6" style={{ backgroundColor: '#1a1a2e' }}>
                        <div
                          className="rounded-lg p-6 min-h-[200px]"
                          style={{ backgroundColor: '#ffffff', color: '#000000' }}
                        >
                          {selectedReceivedEmail.body_html ? (
                            <div
                              style={{ color: '#000000' }}
                              dangerouslySetInnerHTML={{ __html: selectedReceivedEmail.body_html }}
                            />
                          ) : (
                            <pre
                              className="whitespace-pre-wrap font-sans text-base leading-relaxed"
                              style={{ color: '#000000', backgroundColor: '#ffffff' }}
                            >
                              {selectedReceivedEmail.body_text}
                            </pre>
                          )}
                        </div>
                      </div>

                      {/* フッター */}
                      <div className="bg-gray-800 border-t border-gray-600 p-4 flex-shrink-0 flex justify-between items-center">
                        <div className="flex gap-2">
                          <Button
                            onClick={() => setSelectedReceivedEmail(null)}
                            variant="outline"
                            className="bg-gray-700 text-white border-gray-600 hover:bg-gray-600"
                          >
                            閉じる
                          </Button>
                          <Button
                            onClick={() => deleteReceivedEmail(selectedReceivedEmail.id)}
                            variant="outline"
                            className="bg-red-900 text-red-300 border-red-700 hover:bg-red-800"
                          >
                            <Trash2 className="w-4 h-4 mr-2" />
                            削除
                          </Button>
                        </div>
                        <Button
                          onClick={() => {
                            alert("返信機能は準備中です")
                          }}
                          className="bg-orange-600 hover:bg-orange-700 px-6"
                        >
                          <Send className="w-4 h-4 mr-2" />
                          返信する
                        </Button>
                      </div>
                    </Card>
                  </div>
                )}
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
                                {/* 未送信がある場合は再送信ボタンを表示 */}
                                {(email.pending_count > 0 || email.total_recipients - email.sent_count - email.failed_count > 0) && (
                                  <Button
                                    onClick={() => resendPendingEmails(
                                      email.email_id,
                                      email.pending_count || (email.total_recipients - email.sent_count - email.failed_count)
                                    )}
                                    disabled={resendingEmailId !== null}
                                    size="sm"
                                    className={`mt-2 text-white ${
                                      resendingEmailId === email.email_id
                                        ? "bg-yellow-600 animate-pulse"
                                        : "bg-orange-600 hover:bg-orange-700"
                                    }`}
                                  >
                                    <RotateCcw className={`w-3 h-3 mr-1 ${resendingEmailId === email.email_id ? "animate-spin" : ""}`} />
                                    {resendingEmailId === email.email_id
                                      ? "送信中..."
                                      : `未送信 ${email.pending_count || (email.total_recipients - email.sent_count - email.failed_count)}件 再送信`
                                    }
                                  </Button>
                                )}
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
