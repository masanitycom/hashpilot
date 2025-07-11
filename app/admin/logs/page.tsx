"use client"

import React, { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Alert, AlertDescription } from "@/components/ui/alert"
import {
  ArrowLeft,
  Shield,
  Activity,
  AlertTriangle,
  CheckCircle,
  XCircle,
  Info,
  RefreshCw,
  Download,
  Clock
} from "lucide-react"
import { supabase } from "@/lib/supabase"

interface SystemLog {
  id: string
  log_type: string
  operation: string
  user_id: string | null
  message: string
  details: any
  created_at: string
}

interface HealthCheck {
  component: string
  status: string
  message: string
  last_check: string
  details: any
}

export default function AdminLogsPage() {
  const [logs, setLogs] = useState<SystemLog[]>([])
  const [healthChecks, setHealthChecks] = useState<HealthCheck[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")
  const [currentUser, setCurrentUser] = useState<any>(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [logTypeFilter, setLogTypeFilter] = useState("all")
  const [operationFilter, setOperationFilter] = useState("all")
  const [filteredLogs, setFilteredLogs] = useState<SystemLog[]>([])
  const router = useRouter()

  useEffect(() => {
    checkAdminAccess()
  }, [])

  useEffect(() => {
    if (logs.length > 0) {
      filterLogs()
    }
  }, [logs, logTypeFilter, operationFilter])

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
      
      // 緊急対応: basarasystems@gmail.com と support@dshsupport.biz のアクセス許可
      if (user.email === "basarasystems@gmail.com" || user.email === "support@dshsupport.biz") {
        setIsAdmin(true)
        await Promise.all([fetchLogs(), fetchHealthChecks()])
        return
      }

      // 通常の管理者チェック
      const { data: adminCheck, error: adminError } = await supabase.rpc("is_admin", {
        user_email: user.email,
      })

      if (adminError || !adminCheck) {
        setError("管理者権限がありません")
        router.push("/admin")
        return
      }

      setIsAdmin(true)
      await Promise.all([fetchLogs(), fetchHealthChecks()])
    } catch (error) {
      console.error("Admin access check error:", error)
      setError("管理者権限の確認でエラーが発生しました")
    }
  }

  const fetchLogs = async () => {
    try {
      setLoading(true)
      const { data, error } = await supabase.rpc("get_system_logs", {
        p_log_type: null,
        p_operation: null,
        p_limit: 100
      })

      if (error) throw error
      setLogs(data || [])
    } catch (error: any) {
      console.error("ログ取得エラー:", error)
      setError("システムログの取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  const fetchHealthChecks = async () => {
    try {
      const { data, error } = await supabase.rpc("system_health_check")

      if (error) throw error
      setHealthChecks(data || [])
    } catch (error: any) {
      console.error("ヘルスチェック取得エラー:", error)
    }
  }

  const filterLogs = () => {
    let filtered = logs

    if (logTypeFilter !== "all") {
      filtered = filtered.filter(log => log.log_type === logTypeFilter)
    }

    if (operationFilter !== "all") {
      filtered = filtered.filter(log => log.operation === operationFilter)
    }

    setFilteredLogs(filtered)
  }

  const getLogTypeIcon = (logType: string) => {
    switch (logType) {
      case "ERROR":
        return <XCircle className="h-4 w-4 text-red-400" />
      case "WARNING":
        return <AlertTriangle className="h-4 w-4 text-yellow-400" />
      case "SUCCESS":
        return <CheckCircle className="h-4 w-4 text-green-400" />
      case "INFO":
        return <Info className="h-4 w-4 text-blue-400" />
      default:
        return <Clock className="h-4 w-4 text-gray-400" />
    }
  }

  const getLogTypeColor = (logType: string) => {
    switch (logType) {
      case "ERROR":
        return "bg-red-600"
      case "WARNING":
        return "bg-yellow-600"
      case "SUCCESS":
        return "bg-green-600"
      case "INFO":
        return "bg-blue-600"
      default:
        return "bg-gray-600"
    }
  }

  const getHealthStatusIcon = (status: string) => {
    switch (status) {
      case "healthy":
        return <CheckCircle className="h-4 w-4 text-green-400" />
      case "warning":
        return <AlertTriangle className="h-4 w-4 text-yellow-400" />
      case "error":
        return <XCircle className="h-4 w-4 text-red-400" />
      default:
        return <Info className="h-4 w-4 text-gray-400" />
    }
  }

  const getHealthStatusColor = (status: string) => {
    switch (status) {
      case "healthy":
        return "bg-green-600"
      case "warning":
        return "bg-yellow-600"
      case "error":
        return "bg-red-600"
      default:
        return "bg-gray-600"
    }
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString("ja-JP", {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit"
    })
  }

  const exportLogs = () => {
    const csvContent = [
      ["日時", "タイプ", "操作", "ユーザーID", "メッセージ"].join(","),
      ...filteredLogs.map(log => [
        formatDate(log.created_at),
        log.log_type,
        log.operation,
        log.user_id || "",
        `"${log.message.replace(/"/g, '""')}"`
      ].join(","))
    ].join("\n")

    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" })
    const link = document.createElement("a")
    const url = URL.createObjectURL(blob)
    link.setAttribute("href", url)
    link.setAttribute("download", `system_logs_${new Date().toISOString().split('T')[0]}.csv`)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
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
              onClick={() => router.push("/admin")}
              className="mt-4 w-full bg-blue-600 hover:bg-blue-700 text-white"
            >
              管理者ダッシュボードに戻る
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  const errorCount = logs.filter(l => l.log_type === "ERROR").length
  const warningCount = logs.filter(l => l.log_type === "WARNING").length
  const successCount = logs.filter(l => l.log_type === "SUCCESS").length

  return (
    <div className="min-h-screen bg-gray-900">
      <div className="max-w-7xl mx-auto p-4 space-y-6">
        {/* ヘッダー */}
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <Button
              onClick={() => router.push("/admin")}
              variant="outline"
              size="sm"
              className="bg-gray-700 hover:bg-gray-600 text-white border-gray-600"
            >
              <ArrowLeft className="w-4 h-4 mr-2" />
              管理者ダッシュボード
            </Button>
            <h1 className="text-3xl font-bold text-white flex items-center">
              <Activity className="w-8 h-8 mr-3 text-blue-400" />
              システムログ
            </h1>
          </div>
          <div className="flex items-center gap-4">
            <Button
              onClick={exportLogs}
              variant="outline"
              size="sm"
              className="bg-gray-700 hover:bg-gray-600 text-white border-gray-600"
            >
              <Download className="w-4 h-4 mr-2" />
              CSV出力
            </Button>
            <Button
              onClick={() => Promise.all([fetchLogs(), fetchHealthChecks()])}
              variant="outline"
              size="sm"
              className="bg-gray-700 hover:bg-gray-600 text-white border-gray-600"
            >
              <RefreshCw className="w-4 h-4 mr-2" />
              更新
            </Button>
            <Badge className="bg-blue-600 text-white text-sm">{currentUser?.email}</Badge>
          </div>
        </div>

        {/* ヘルスチェック */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white">システム状況</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
              {healthChecks.map((check) => (
                <div
                  key={check.component}
                  className="bg-gray-700/50 border border-gray-600 rounded-lg p-3"
                >
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-white text-sm font-medium">
                      {check.component.replace(/_/g, " ")}
                    </span>
                    {getHealthStatusIcon(check.status)}
                  </div>
                  <div className="text-lg font-bold text-white mb-1">
                    {check.message}
                  </div>
                  <Badge className={`${getHealthStatusColor(check.status)} text-xs`}>
                    {check.status}
                  </Badge>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* ログ統計 */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Card className="bg-gradient-to-br from-red-900 to-red-800 border-red-700">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium flex items-center gap-2 text-red-100">
                <XCircle className="h-4 w-4" />
                エラー
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-white">{errorCount}件</div>
              <p className="text-xs text-red-200">要確認</p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-yellow-900 to-yellow-800 border-yellow-700">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium flex items-center gap-2 text-yellow-100">
                <AlertTriangle className="h-4 w-4" />
                警告
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-white">{warningCount}件</div>
              <p className="text-xs text-yellow-200">注意</p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-green-900 to-green-800 border-green-700">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium flex items-center gap-2 text-green-100">
                <CheckCircle className="h-4 w-4" />
                成功
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-white">{successCount}件</div>
              <p className="text-xs text-green-200">正常</p>
            </CardContent>
          </Card>
        </div>

        {/* ログ一覧 */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="text-white">システムログ一覧</CardTitle>
              <div className="flex gap-2">
                <Select value={logTypeFilter} onValueChange={setLogTypeFilter}>
                  <SelectTrigger className="w-32 bg-gray-700 border-gray-600 text-white">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">全タイプ</SelectItem>
                    <SelectItem value="ERROR">エラー</SelectItem>
                    <SelectItem value="WARNING">警告</SelectItem>
                    <SelectItem value="SUCCESS">成功</SelectItem>
                    <SelectItem value="INFO">情報</SelectItem>
                  </SelectContent>
                </Select>
                <Select value={operationFilter} onValueChange={setOperationFilter}>
                  <SelectTrigger className="w-40 bg-gray-700 border-gray-600 text-white">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">全操作</SelectItem>
                    <SelectItem value="DAILY_YIELD">日利処理</SelectItem>
                    <SelectItem value="AUTO_PURCHASE">自動購入</SelectItem>
                    <SelectItem value="WITHDRAWAL_REQUEST">出金申請</SelectItem>
                    <SelectItem value="WITHDRAWAL_APPROVED">出金承認</SelectItem>
                    <SelectItem value="DAILY_BATCH">日次バッチ</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
          </CardHeader>
          <CardContent>
            {loading ? (
              <div className="text-center py-8">
                <div className="text-white">読み込み中...</div>
              </div>
            ) : filteredLogs.length === 0 ? (
              <div className="text-center py-8">
                <p className="text-gray-400">ログがありません</p>
              </div>
            ) : (
              <div className="space-y-2 max-h-96 overflow-y-auto">
                {filteredLogs.map((log) => (
                  <div
                    key={log.id}
                    className="bg-gray-700/50 border border-gray-600 rounded-lg p-3 space-y-2"
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        {getLogTypeIcon(log.log_type)}
                        <Badge className={getLogTypeColor(log.log_type)}>
                          {log.log_type}
                        </Badge>
                        <Badge variant="outline" className="border-gray-500 text-gray-300">
                          {log.operation}
                        </Badge>
                        {log.user_id && (
                          <Badge variant="outline" className="border-blue-500 text-blue-300">
                            {log.user_id}
                          </Badge>
                        )}
                      </div>
                      <span className="text-gray-400 text-sm">
                        {formatDate(log.created_at)}
                      </span>
                    </div>

                    <div className="text-white text-sm">
                      {log.message}
                    </div>

                    {log.details && Object.keys(log.details).length > 0 && (
                      <details className="text-xs">
                        <summary className="text-gray-400 cursor-pointer hover:text-white">
                          詳細情報
                        </summary>
                        <pre className="text-gray-300 mt-1 bg-gray-800 p-2 rounded overflow-x-auto">
                          {JSON.stringify(log.details, null, 2)}
                        </pre>
                      </details>
                    )}
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        {error && (
          <Alert className="border-red-500 bg-red-900/20">
            <AlertDescription className="text-red-300">{error}</AlertDescription>
          </Alert>
        )}
      </div>
    </div>
  )
}