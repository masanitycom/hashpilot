"use client"

import { useEffect, useState } from "react"
import { Card, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Megaphone, X } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface Announcement {
  id: number
  title: string
  content: string
  priority: number
  created_at: string
}

export function AnnouncementsBanner() {
  const [announcements, setAnnouncements] = useState<Announcement[]>([])
  const [dismissedIds, setDismissedIds] = useState<Set<number>>(new Set())
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchAnnouncements()
    // ローカルストレージから非表示リストを読み込み
    const dismissed = localStorage.getItem('dismissed_announcements')
    if (dismissed) {
      setDismissedIds(new Set(JSON.parse(dismissed)))
    }
  }, [])

  const fetchAnnouncements = async () => {
    try {
      const { data, error } = await supabase
        .from('announcements')
        .select('*')
        .eq('is_active', true)
        .order('priority', { ascending: false })
        .order('created_at', { ascending: false })
        .limit(5)

      if (error) throw error
      setAnnouncements(data || [])
    } catch (error) {
      console.error('お知らせ取得エラー:', error)
    } finally {
      setLoading(false)
    }
  }

  const dismissAnnouncement = (id: number) => {
    const newDismissed = new Set(dismissedIds)
    newDismissed.add(id)
    setDismissedIds(newDismissed)
    localStorage.setItem('dismissed_announcements', JSON.stringify([...newDismissed]))
  }

  // URLをリンクに変換する関数
  const linkifyText = (text: string) => {
    const urlRegex = /(https?:\/\/[^\s]+)/g
    return text.split(urlRegex).map((part, index) => {
      if (part.match(urlRegex)) {
        return (
          <a
            key={index}
            href={part}
            target="_blank"
            rel="noopener noreferrer"
            className="text-cyan-300 hover:text-cyan-200 underline font-bold"
          >
            {part}
          </a>
        )
      }
      return part
    })
  }

  // 改行を<br>に変換
  const formatContent = (content: string) => {
    return content.split('\n').map((line, index, array) => (
      <span key={index}>
        {linkifyText(line)}
        {index < array.length - 1 && <br />}
      </span>
    ))
  }

  const visibleAnnouncements = announcements.filter(a => !dismissedIds.has(a.id))

  if (loading || visibleAnnouncements.length === 0) {
    return null
  }

  return (
    <div className="space-y-3 mb-6">
      {visibleAnnouncements.map((announcement) => (
        <Card
          key={announcement.id}
          className="bg-gradient-to-r from-blue-900 to-purple-900 border-blue-500"
        >
          <CardContent className="p-4">
            <div className="flex items-start gap-3">
              <Megaphone className="h-5 w-5 text-yellow-400 flex-shrink-0 mt-1" />
              <div className="flex-1 min-w-0">
                <div className="flex items-start justify-between gap-2 mb-2">
                  <h3 className="text-white font-bold text-lg">
                    {announcement.title}
                  </h3>
                  <button
                    onClick={() => dismissAnnouncement(announcement.id)}
                    className="text-gray-300 hover:text-white transition-colors flex-shrink-0"
                    aria-label="閉じる"
                  >
                    <X className="h-5 w-5" />
                  </button>
                </div>
                <div className="text-white text-base font-medium whitespace-pre-wrap break-words">
                  {formatContent(announcement.content)}
                </div>
                <div className="text-xs text-gray-300 mt-3">
                  {new Date(announcement.created_at).toLocaleDateString('ja-JP', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric'
                  })}
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  )
}
