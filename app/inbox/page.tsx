"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { Mail, MailOpen, RefreshCw, X } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface Email {
  email_id: string
  subject: string
  body: string
  from_name: string
  status: string
  created_at: string
  sent_at: string | null
  read_at: string | null
}

export default function InboxPage() {
  const [currentUser, setCurrentUser] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [emails, setEmails] = useState<Email[]>([])
  const [selectedEmail, setSelectedEmail] = useState<Email | null>(null)
  const router = useRouter()

  useEffect(() => {
    checkAuth()
  }, [])

  const checkAuth = async () => {
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) {
        router.push("/login")
        return
      }

      setCurrentUser(user)
      fetchEmails(user.email!)
    } catch (error) {
      console.error("Auth check error:", error)
    } finally {
      setLoading(false)
    }
  }

  const fetchEmails = async (userEmail: string) => {
    try {
      const { data, error } = await supabase.rpc("get_user_emails", {
        p_user_email: userEmail,
      })

      if (error) throw error
      setEmails(data || [])
    } catch (error: any) {
      console.error("Error fetching emails:", error)
    }
  }

  const markAsRead = async (emailId: string) => {
    try {
      const { error } = await supabase.rpc("mark_email_as_read", {
        p_email_id: emailId,
        p_user_email: currentUser.email,
      })

      if (error) throw error

      // メール一覧を更新
      fetchEmails(currentUser.email)
    } catch (error: any) {
      console.error("Error marking email as read:", error)
    }
  }

  const openEmail = (email: Email) => {
    setSelectedEmail(email)
    // 未読の場合は既読にする
    if (email.status !== "read") {
      markAsRead(email.email_id)
    }
  }

  const unreadCount = emails.filter((email) => email.status !== "read").length

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

  return (
    <div className="min-h-screen bg-gray-900 p-4">
      <div className="max-w-4xl mx-auto">
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="text-white flex items-center">
                <Mail className="w-5 h-5 mr-2" />
                受信箱
                {unreadCount > 0 && (
                  <Badge className="ml-2 bg-red-600">{unreadCount}件未読</Badge>
                )}
              </CardTitle>
              <div className="flex space-x-2">
                <Button
                  onClick={() => fetchEmails(currentUser.email)}
                  size="sm"
                  variant="outline"
                  className="bg-gray-700 text-white border-gray-600"
                >
                  <RefreshCw className="w-4 h-4 mr-2" />
                  更新
                </Button>
                <Button
                  onClick={() => router.push("/dashboard")}
                  size="sm"
                  variant="outline"
                  className="bg-blue-600 hover:bg-blue-700 text-white border-blue-600"
                >
                  ダッシュボード
                </Button>
              </div>
            </div>
          </CardHeader>
          <CardContent>
            {emails.length === 0 ? (
              <div className="text-center py-12 text-gray-400">
                <Mail className="w-16 h-16 mx-auto mb-4 opacity-50" />
                <p>メールはありません</p>
              </div>
            ) : (
              <div className="space-y-2">
                {emails.map((email) => (
                  <Dialog key={email.email_id}>
                    <DialogTrigger asChild>
                      <div
                        onClick={() => openEmail(email)}
                        className={`p-4 rounded-lg cursor-pointer transition-colors ${
                          email.status === "read"
                            ? "bg-gray-700 hover:bg-gray-650"
                            : "bg-blue-900/30 hover:bg-blue-900/40 border border-blue-600"
                        }`}
                      >
                        <div className="flex items-start justify-between">
                          <div className="flex-1">
                            <div className="flex items-center space-x-2">
                              {email.status === "read" ? (
                                <MailOpen className="w-4 h-4 text-gray-400" />
                              ) : (
                                <Mail className="w-4 h-4 text-blue-400" />
                              )}
                              <h4
                                className={`font-semibold ${
                                  email.status === "read" ? "text-gray-300" : "text-white"
                                }`}
                              >
                                {email.subject}
                              </h4>
                            </div>
                            <p className="text-sm text-gray-400 mt-1">
                              差出人: {email.from_name}
                            </p>
                            <p className="text-xs text-gray-500 mt-1">
                              {new Date(email.created_at).toLocaleString("ja-JP")}
                            </p>
                          </div>
                          <div>
                            {email.status === "read" ? (
                              <Badge variant="outline" className="text-gray-400">
                                既読
                              </Badge>
                            ) : (
                              <Badge className="bg-blue-600">未読</Badge>
                            )}
                          </div>
                        </div>
                      </div>
                    </DialogTrigger>

                    <DialogContent
                      className="bg-gray-800 border-gray-700 text-white max-w-3xl max-h-[80vh] overflow-y-auto"
                      aria-describedby="email-dialog-description"
                    >
                      <DialogHeader>
                        <DialogTitle className="text-xl">{email.subject}</DialogTitle>
                      </DialogHeader>
                      <div id="email-dialog-description" className="text-gray-400 text-sm mb-4">
                        差出人: {email.from_name} | 受信日時:{" "}
                        {new Date(email.created_at).toLocaleString("ja-JP")}
                      </div>
                      <div
                        className="prose prose-invert max-w-none"
                        dangerouslySetInnerHTML={{ __html: email.body }}
                      />
                    </DialogContent>
                  </Dialog>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
