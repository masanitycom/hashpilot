"use client"

import { Badge } from "@/components/ui/badge"
import { CalendarDays, TrendingUp, Clock } from "lucide-react"

interface OperationStatusProps {
  approvalDate: string | null
  variant?: "default" | "compact"
}

export function OperationStatus({ approvalDate, variant = "default" }: OperationStatusProps) {
  if (!approvalDate) {
    return (
      <div className="flex items-center gap-2">
        <Badge variant="secondary" className="flex items-center gap-1">
          <Clock className="h-3 w-3" />
          未承認
        </Badge>
      </div>
    )
  }

  const approval = new Date(approvalDate)
  const operationStart = new Date(approval.getTime() + 15 * 24 * 60 * 60 * 1000) // 15日後
  const today = new Date()
  
  // 日付のみで比較（時間を無視）
  const approvalDateOnly = new Date(approval.getFullYear(), approval.getMonth(), approval.getDate())
  const operationStartDateOnly = new Date(operationStart.getFullYear(), operationStart.getMonth(), operationStart.getDate())
  const todayDateOnly = new Date(today.getFullYear(), today.getMonth(), today.getDate())
  
  const isOperating = todayDateOnly >= operationStartDateOnly
  const daysUntilStart = Math.ceil((operationStartDateOnly.getTime() - todayDateOnly.getTime()) / (1000 * 60 * 60 * 24))
  
  const formatDate = (date: Date) => {
    return date.toLocaleDateString('ja-JP', {
      year: 'numeric',
      month: 'numeric',
      day: 'numeric'
    })
  }

  if (variant === "compact") {
    return (
      <div className="flex items-center gap-2">
        {isOperating ? (
          <Badge variant="default" className="bg-green-600 flex items-center gap-1">
            <TrendingUp className="h-3 w-3" />
            運用中
          </Badge>
        ) : (
          <Badge variant="outline" className="border-orange-300 text-orange-700 flex items-center gap-1">
            <CalendarDays className="h-3 w-3" />
            {formatDate(operationStart)}開始
          </Badge>
        )}
      </div>
    )
  }

  return (
    <div className="space-y-2">
      <div className="flex items-center gap-2">
        <CalendarDays className="h-4 w-4 text-gray-500" />
        <span className="text-sm font-medium">運用ステータス</span>
      </div>
      
      <div className="flex items-center gap-3">
        {isOperating ? (
          <>
            <Badge variant="default" className="bg-green-600 flex items-center gap-1">
              <TrendingUp className="h-3 w-3" />
              運用中
            </Badge>
            <span className="text-sm text-gray-600">
              {formatDate(operationStart)}より運用開始済み
            </span>
          </>
        ) : (
          <>
            <Badge variant="outline" className="border-orange-300 text-orange-700 flex items-center gap-1">
              <Clock className="h-3 w-3" />
              運用待機中
            </Badge>
            <span className="text-sm text-gray-600">
              {formatDate(operationStart)}より運用開始
              {daysUntilStart > 0 && (
                <span className="text-orange-600 font-medium ml-1">
                  (あと{daysUntilStart}日)
                </span>
              )}
            </span>
          </>
        )}
      </div>
      
      <div className="text-xs text-gray-500">
        承認日: {formatDate(approval)}
      </div>
    </div>
  )
}