"use client"

import { useEffect, useState } from "react"
import { Card, CardContent } from "@/components/ui/card"
import { Megaphone, ChevronDown, X } from "lucide-react"
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
  const [loading, setLoading] = useState(true)
  const [expandedId, setExpandedId] = useState<number | null>(null)

  useEffect(() => {
    fetchAnnouncements()
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

  const open = (id: number) => {
    setExpandedId(id)
  }

  const close = () => {
    setExpandedId(null)
  }

  // URLをリンクに変換
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
            onClick={(e) => e.stopPropagation()}
          >
            {part}
          </a>
        )
      }
      return part
    })
  }

  const formatContent = (content: string) => {
    return content.split('\n').map((line, index, array) => (
      <span key={index}>
        {linkifyText(line)}
        {index < array.length - 1 && <br />}
      </span>
    ))
  }

  if (loading || announcements.length === 0) {
    return null
  }

  return (
    <div className="space-y-3 mb-6">
      {announcements.map((announcement) => {
        const isOpen = expandedId === announcement.id
        return (
          <Card
            key={announcement.id}
            className="bg-gradient-to-r from-blue-900 to-purple-900 border-blue-500 overflow-hidden"
          >
            <button
              type="button"
              onClick={() => open(announcement.id)}
              disabled={isOpen}
              className={`w-full text-left transition-colors ${
                isOpen ? 'cursor-default' : 'hover:bg-white/5'
              }`}
              aria-expanded={isOpen}
            >
              <div className="p-4 flex items-start gap-3">
                <Megaphone className="h-5 w-5 text-yellow-400 flex-shrink-0 mt-1" />
                <div className="flex-1 min-w-0">
                  <h3 className="text-white font-bold text-lg">
                    {announcement.title}
                  </h3>
                  <div className="text-xs text-gray-300 mt-1">
                    {new Date(announcement.created_at).toLocaleDateString('ja-JP', {
                      year: 'numeric',
                      month: 'long',
                      day: 'numeric'
                    })}
                  </div>
                </div>
                {!isOpen && (
                  <div className="flex-shrink-0 flex items-center gap-1 text-gray-200 text-sm bg-white/10 px-3 py-1 rounded-lg border border-white/20">
                    <span>詳細を見る</span>
                    <ChevronDown className="h-4 w-4" />
                  </div>
                )}
              </div>
            </button>

            {isOpen && (
              <CardContent className="pt-0 pb-4 px-4">
                <div className="border-t border-white/20 pt-4">
                  <div className="text-white text-base font-medium whitespace-pre-wrap break-words">
                    {formatContent(announcement.content)}
                  </div>
                  <div className="mt-4 flex justify-center">
                    <button
                      type="button"
                      onClick={close}
                      className="inline-flex items-center gap-2 bg-red-600 hover:bg-red-700 text-white font-bold px-6 py-3 rounded-lg border-2 border-red-400 shadow-lg transition-colors"
                    >
                      <X className="h-5 w-5" />
                      閉じる
                    </button>
                  </div>
                </div>
              </CardContent>
            )}
          </Card>
        )
      })}
    </div>
  )
}
