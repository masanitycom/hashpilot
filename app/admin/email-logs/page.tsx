"use client"

import { useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { supabase } from "@/lib/supabase"

interface EmailLog {
  email: string
  created_at: string
  email_confirmed_at: string | null
  last_sign_in_at: string | null
  confirmation_sent_at: string | null
}

export default function EmailLogsPage() {
  const [emailLogs, setEmailLogs] = useState<EmailLog[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchEmailLogs()
  }, [])

  const fetchEmailLogs = async () => {
    try {
      const { data, error } = await supabase
        .from("auth.users")
        .select("email, created_at, email_confirmed_at, last_sign_in_at, confirmation_sent_at")
        .order("created_at", { ascending: false })
        .limit(20)

      if (error) throw error
      setEmailLogs(data || [])
    } catch (error) {
      console.error("Error fetching email logs:", error)
    } finally {
      setLoading(false)
    }
  }

  const formatDate = (dateString: string | null) => {
    if (!dateString) return "未確認"
    return new Date(dateString).toLocaleString("ja-JP")
  }

  const getStatusBadge = (confirmedAt: string | null) => {
    if (confirmedAt) {
      return <Badge className="bg-green-600">確認済み</Badge>
    }
    return <Badge variant="destructive">未確認</Badge>
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="text-white">読み込み中...</div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-black p-4">
      <div className="max-w-6xl mx-auto">
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white">メール送信ログ</CardTitle>
            <Button onClick={fetchEmailLogs} className="w-fit">
              更新
            </Button>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full text-white">
                <thead>
                  <tr className="border-b border-gray-600">
                    <th className="text-left p-2">メールアドレス</th>
                    <th className="text-left p-2">登録日時</th>
                    <th className="text-left p-2">確認状態</th>
                    <th className="text-left p-2">確認日時</th>
                    <th className="text-left p-2">最終ログイン</th>
                  </tr>
                </thead>
                <tbody>
                  {emailLogs.map((log, index) => (
                    <tr key={index} className="border-b border-gray-700">
                      <td className="p-2">{log.email}</td>
                      <td className="p-2">{formatDate(log.created_at)}</td>
                      <td className="p-2">{getStatusBadge(log.email_confirmed_at)}</td>
                      <td className="p-2">{formatDate(log.email_confirmed_at)}</td>
                      <td className="p-2">{formatDate(log.last_sign_in_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
