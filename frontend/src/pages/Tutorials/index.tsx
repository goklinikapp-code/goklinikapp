import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { isAxiosError } from 'axios'
import { CheckCircle2, Circle, GripVertical, Pencil, Plus, Trash2 } from 'lucide-react'
import toast from 'react-hot-toast'

import {
  createTutorial,
  deleteTutorial,
  getTutorials,
  updateTutorial,
  updateTutorialProgress,
  type TutorialVideo,
} from '@/api/tutorials'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Badge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Input } from '@/components/ui/Input'
import { Modal } from '@/components/ui/Modal'
import { TextArea } from '@/components/ui/TextArea'
import { usePreferencesStore } from '@/stores/preferencesStore'
import { useAuthStore } from '@/stores/authStore'
import { formatDate } from '@/utils/format'

type TutorialCopy = {
  pageTitle: string
  pageSubtitleClinic: string
  pageSubtitleSaas: string
  saasStatsTitle: string
  saasTotalVideos: string
  saasPublishedVideos: string
  saasDraftVideos: string
  progressTitle: string
  completed: string
  remaining: string
  watchListTitle: string
  watchListSubtitle: string
  emptyList: string
  noVideoSelected: string
  markComplete: string
  markIncomplete: string
  progressSaved: string
  progressError: string
  reorderHint: string
  reorderSaved: string
  reorderError: string
  loading: string
  loadError: string
  newVideo: string
  manageTitle: string
  manageSubtitle: string
  colTitle: string
  colThumbnail: string
  colOrder: string
  colStatus: string
  colActions: string
  published: string
  draft: string
  edit: string
  delete: string
  save: string
  saving: string
  cancel: string
  modalCreateTitle: string
  modalEditTitle: string
  fieldTitle: string
  fieldDescription: string
  fieldYoutubeUrl: string
  fieldThumbnailPreview: string
  fieldThumbnailAutoHint: string
  fieldOrder: string
  fieldPublished: string
  placeholderTitle: string
  placeholderDescription: string
  placeholderYoutube: string
  placeholderThumbnail: string
  created: string
  updated: string
  noDescription: string
  noThumbnail: string
  deleteConfirm: string
  createSuccess: string
  updateSuccess: string
  deleteSuccess: string
  saveError: string
  deleteError: string
}

const COPY_BY_LANGUAGE: Record<string, TutorialCopy> = {
  pt: {
    pageTitle: 'Tutoriais',
    pageSubtitleClinic:
      'Aprenda a usar o sistema com vídeos em formato de curso. Você pode assistir em qualquer ordem.',
    pageSubtitleSaas:
      'Gerencie os vídeos do curso para todas as clínicas.',
    saasStatsTitle: 'Resumo dos tutoriais',
    saasTotalVideos: 'Total de vídeos',
    saasPublishedVideos: 'Publicados',
    saasDraftVideos: 'Rascunhos',
    progressTitle: 'Seu progresso no curso',
    completed: 'Concluídos',
    remaining: 'Restantes',
    watchListTitle: 'Aulas',
    watchListSubtitle: 'Clique para assistir. Você pode avançar livremente entre os vídeos.',
    emptyList: 'Nenhum tutorial cadastrado ainda.',
    noVideoSelected: 'Selecione uma aula para começar.',
    markComplete: 'Marcar como concluído',
    markIncomplete: 'Marcar como não concluído',
    progressSaved: 'Progresso atualizado',
    progressError: 'Não foi possível atualizar o progresso',
    reorderHint: 'Arraste os vídeos para definir a ordem do curso.',
    reorderSaved: 'Ordem dos vídeos atualizada',
    reorderError: 'Não foi possível atualizar a ordem dos vídeos',
    loading: 'Carregando tutoriais...',
    loadError: 'Não foi possível carregar os tutoriais.',
    newVideo: 'Novo vídeo',
    manageTitle: 'Gerenciar vídeos',
    manageSubtitle:
      'Os vídeos publicados aqui aparecem automaticamente para todos os donos de clínicas.',
    colTitle: 'TÍTULO',
    colThumbnail: 'THUMBNAIL',
    colOrder: 'ORDEM',
    colStatus: 'STATUS',
    colActions: 'AÇÕES',
    published: 'Publicado',
    draft: 'Rascunho',
    edit: 'Editar',
    delete: 'Excluir',
    save: 'Salvar',
    saving: 'Salvando...',
    cancel: 'Cancelar',
    modalCreateTitle: 'Novo tutorial',
    modalEditTitle: 'Editar tutorial',
    fieldTitle: 'Título',
    fieldDescription: 'Descrição',
    fieldYoutubeUrl: 'URL do YouTube',
    fieldThumbnailPreview: 'Prévia da thumbnail',
    fieldThumbnailAutoHint: 'A thumbnail é preenchida automaticamente a partir do link do YouTube.',
    fieldOrder: 'Ordem',
    fieldPublished: 'Publicado para as clínicas',
    placeholderTitle: 'Ex.: Como cadastrar um paciente',
    placeholderDescription: 'Descreva rapidamente o conteúdo da aula',
    placeholderYoutube: 'https://www.youtube.com/watch?v=...',
    placeholderThumbnail: 'https://...',
    created: 'Criado em',
    updated: 'Atualizado em',
    noDescription: 'Sem descrição.',
    noThumbnail: 'Sem thumbnail',
    deleteConfirm: 'Deseja realmente excluir este tutorial?',
    createSuccess: 'Tutorial criado com sucesso',
    updateSuccess: 'Tutorial atualizado com sucesso',
    deleteSuccess: 'Tutorial excluído com sucesso',
    saveError: 'Não foi possível salvar o tutorial',
    deleteError: 'Não foi possível excluir o tutorial',
  },
  en: {
    pageTitle: 'Tutorials',
    pageSubtitleClinic:
      'Learn how to use the system with course-style videos. You can watch in any order.',
    pageSubtitleSaas:
      'Manage course videos for all clinics.',
    saasStatsTitle: 'Tutorial summary',
    saasTotalVideos: 'Total videos',
    saasPublishedVideos: 'Published',
    saasDraftVideos: 'Drafts',
    progressTitle: 'Your course progress',
    completed: 'Completed',
    remaining: 'Remaining',
    watchListTitle: 'Lessons',
    watchListSubtitle: 'Click to watch. You can freely jump between videos.',
    emptyList: 'No tutorials available yet.',
    noVideoSelected: 'Select a lesson to start.',
    markComplete: 'Mark as completed',
    markIncomplete: 'Mark as not completed',
    progressSaved: 'Progress updated',
    progressError: 'Could not update progress',
    reorderHint: 'Drag videos to define the course order.',
    reorderSaved: 'Video order updated',
    reorderError: 'Could not update video order',
    loading: 'Loading tutorials...',
    loadError: 'Could not load tutorials.',
    newVideo: 'New video',
    manageTitle: 'Manage videos',
    manageSubtitle: 'Published videos appear automatically for every clinic owner.',
    colTitle: 'TITLE',
    colThumbnail: 'THUMBNAIL',
    colOrder: 'ORDER',
    colStatus: 'STATUS',
    colActions: 'ACTIONS',
    published: 'Published',
    draft: 'Draft',
    edit: 'Edit',
    delete: 'Delete',
    save: 'Save',
    saving: 'Saving...',
    cancel: 'Cancel',
    modalCreateTitle: 'New tutorial',
    modalEditTitle: 'Edit tutorial',
    fieldTitle: 'Title',
    fieldDescription: 'Description',
    fieldYoutubeUrl: 'YouTube URL',
    fieldThumbnailPreview: 'Thumbnail preview',
    fieldThumbnailAutoHint: 'Thumbnail is filled automatically from the YouTube URL.',
    fieldOrder: 'Order',
    fieldPublished: 'Published for clinics',
    placeholderTitle: 'Ex: How to register a patient',
    placeholderDescription: 'Quickly describe this lesson',
    placeholderYoutube: 'https://www.youtube.com/watch?v=...',
    placeholderThumbnail: 'https://...',
    created: 'Created at',
    updated: 'Updated at',
    noDescription: 'No description.',
    noThumbnail: 'No thumbnail',
    deleteConfirm: 'Do you really want to delete this tutorial?',
    createSuccess: 'Tutorial created successfully',
    updateSuccess: 'Tutorial updated successfully',
    deleteSuccess: 'Tutorial deleted successfully',
    saveError: 'Could not save tutorial',
    deleteError: 'Could not delete tutorial',
  },
}

type TutorialFormState = {
  title: string
  description: string
  youtube_url: string
  thumbnail_url: string
  order_index: string
  is_published: boolean
}

const EMPTY_FORM: TutorialFormState = {
  title: '',
  description: '',
  youtube_url: '',
  thumbnail_url: '',
  order_index: '1',
  is_published: true,
}

function extractErrorMessage(error: unknown, fallback: string): string {
  if (!isAxiosError(error)) return fallback
  const data = error.response?.data as Record<string, unknown> | undefined
  if (!data) return fallback
  if (typeof data.detail === 'string' && data.detail.trim()) return data.detail
  const firstValue = Object.values(data)[0]
  if (typeof firstValue === 'string' && firstValue.trim()) return firstValue
  if (Array.isArray(firstValue) && firstValue.length > 0) return String(firstValue[0])
  return fallback
}

function formFromVideo(video: TutorialVideo): TutorialFormState {
  return {
    title: video.title,
    description: video.description || '',
    youtube_url: video.youtube_url,
    thumbnail_url: video.thumbnail_url || '',
    order_index: String(video.order_index || 1),
    is_published: Boolean(video.is_published),
  }
}

function extractYoutubeVideoId(rawUrl: string): string {
  const clean = (rawUrl || '').trim()
  if (!clean) return ''

  try {
    const parsed = new URL(clean)
    const host = parsed.hostname.toLowerCase()
    const path = parsed.pathname.replace(/^\/+|\/+$/g, '')

    if (host.endsWith('youtu.be')) {
      return path.split('/')[0] || ''
    }

    if (host.includes('youtube.com')) {
      if (path === 'watch') {
        return parsed.searchParams.get('v') || ''
      }
      if (path.startsWith('embed/')) {
        return path.replace('embed/', '').split('/')[0] || ''
      }
      if (path.startsWith('shorts/')) {
        return path.replace('shorts/', '').split('/')[0] || ''
      }
    }
  } catch {
    return ''
  }

  return ''
}

function buildYoutubeThumbnailUrl(rawUrl: string): string {
  const videoId = extractYoutubeVideoId(rawUrl)
  if (!videoId) return ''
  return `https://img.youtube.com/vi/${videoId}/hqdefault.jpg`
}

export default function TutorialsPage() {
  const queryClient = useQueryClient()
  const language = usePreferencesStore((state) => state.language)
  const user = useAuthStore((state) => state.user)
  const isSaasOwner = user?.role === 'super_admin'

  const copy = COPY_BY_LANGUAGE[language] || COPY_BY_LANGUAGE.en

  const [selectedVideoId, setSelectedVideoId] = useState<string | null>(null)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [editingVideo, setEditingVideo] = useState<TutorialVideo | null>(null)
  const [form, setForm] = useState<TutorialFormState>(EMPTY_FORM)
  const [saasOrderedVideos, setSaasOrderedVideos] = useState<TutorialVideo[]>([])
  const [draggedVideoId, setDraggedVideoId] = useState<string | null>(null)

  const { data, isLoading, isError } = useQuery({
    queryKey: ['tutorials'],
    queryFn: getTutorials,
  })

  const videos = data?.videos || []
  const summary = data?.summary || {
    total_videos: 0,
    completed_videos: 0,
    remaining_videos: 0,
    completion_percent: 0,
  }
  const publishedVideos = videos.filter((video) => video.is_published).length
  const draftVideos = Math.max(videos.length - publishedVideos, 0)

  useEffect(() => {
    if (!videos.length) {
      setSelectedVideoId(null)
      return
    }
    const exists = videos.some((video) => video.id === selectedVideoId)
    if (!selectedVideoId || !exists) {
      setSelectedVideoId(videos[0].id)
    }
  }, [videos, selectedVideoId])

  useEffect(() => {
    if (isSaasOwner) {
      setSaasOrderedVideos(videos)
    }
  }, [isSaasOwner, videos])

  useEffect(() => {
    const automaticThumbnail = buildYoutubeThumbnailUrl(form.youtube_url)
    setForm((prev) => {
      if (!automaticThumbnail && !prev.youtube_url.trim()) {
        if (!prev.thumbnail_url) return prev
        return { ...prev, thumbnail_url: '' }
      }
      if (!automaticThumbnail || prev.thumbnail_url === automaticThumbnail) return prev
      return { ...prev, thumbnail_url: automaticThumbnail }
    })
  }, [form.youtube_url])

  const selectedVideo = useMemo(
    () => videos.find((video) => video.id === selectedVideoId) || null,
    [videos, selectedVideoId],
  )

  const progressMutation = useMutation({
    mutationFn: ({ videoId, completed }: { videoId: string; completed: boolean }) =>
      updateTutorialProgress(videoId, completed),
    onSuccess: () => {
      toast.success(copy.progressSaved)
      void queryClient.invalidateQueries({ queryKey: ['tutorials'] })
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, copy.progressError))
    },
  })

  const saveMutation = useMutation({
    mutationFn: ({
      videoId,
      payload,
    }: {
      videoId?: string
      payload: {
        title: string
        description?: string
        youtube_url: string
        thumbnail_url?: string
        order_index: number
        is_published: boolean
      }
    }) => {
      if (videoId) {
        return updateTutorial(videoId, payload)
      }
      return createTutorial(payload)
    },
    onSuccess: () => {
      toast.success(editingVideo ? copy.updateSuccess : copy.createSuccess)
      setIsModalOpen(false)
      setEditingVideo(null)
      setForm(EMPTY_FORM)
      void queryClient.invalidateQueries({ queryKey: ['tutorials'] })
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, copy.saveError))
    },
  })

  const reorderMutation = useMutation({
    mutationFn: async (
      updates: Array<{ id: string; order_index: number; previous_order_index: number }>,
    ) => {
      const changedVideos = updates.filter(
        (video) => video.order_index !== video.previous_order_index,
      )
      await Promise.all(
        changedVideos.map((video) =>
          updateTutorial(video.id, { order_index: video.order_index }),
        ),
      )
    },
    onSuccess: () => {
      toast.success(copy.reorderSaved)
      void queryClient.invalidateQueries({ queryKey: ['tutorials'] })
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, copy.reorderError))
      void queryClient.invalidateQueries({ queryKey: ['tutorials'] })
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (videoId: string) => deleteTutorial(videoId),
    onSuccess: () => {
      toast.success(copy.deleteSuccess)
      setEditingVideo(null)
      setIsModalOpen(false)
      void queryClient.invalidateQueries({ queryKey: ['tutorials'] })
    },
    onError: (error) => {
      toast.error(extractErrorMessage(error, copy.deleteError))
    },
  })

  const openCreateModal = () => {
    const lastOrder = videos.length ? videos[videos.length - 1].order_index : 0
    const nextOrder = lastOrder + 1
    setEditingVideo(null)
    setForm({
      ...EMPTY_FORM,
      order_index: String(nextOrder),
    })
    setIsModalOpen(true)
  }

  const openEditModal = (video: TutorialVideo) => {
    setEditingVideo(video)
    setForm(formFromVideo(video))
    setIsModalOpen(true)
  }

  const handleSaveVideo = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    const orderValue = Number(form.order_index)

    if (!form.title.trim() || !form.youtube_url.trim() || Number.isNaN(orderValue) || orderValue <= 0) {
      toast.error(copy.saveError)
      return
    }

    saveMutation.mutate({
      videoId: editingVideo?.id,
      payload: {
        title: form.title.trim(),
        description: form.description.trim(),
        youtube_url: form.youtube_url.trim(),
        thumbnail_url: form.thumbnail_url.trim(),
        order_index: orderValue,
        is_published: form.is_published,
      },
    })
  }

  const handleDropVideo = (targetVideoId: string) => {
    if (!draggedVideoId || draggedVideoId === targetVideoId) {
      setDraggedVideoId(null)
      return
    }

    const sourceIndex = saasOrderedVideos.findIndex((video) => video.id === draggedVideoId)
    const targetIndex = saasOrderedVideos.findIndex((video) => video.id === targetVideoId)
    if (sourceIndex < 0 || targetIndex < 0) {
      setDraggedVideoId(null)
      return
    }

    const reordered = [...saasOrderedVideos]
    const [moved] = reordered.splice(sourceIndex, 1)
    reordered.splice(targetIndex, 0, moved)
    const updates = reordered.map((video, index) => ({
      id: video.id,
      previous_order_index: video.order_index,
      order_index: index + 1,
    }))
    const normalized = reordered.map((video, index) => ({
      ...video,
      order_index: index + 1,
    }))

    setSaasOrderedVideos(normalized)
    reorderMutation.mutate(updates)
    setDraggedVideoId(null)
  }

  const handleDeleteVideo = (video: TutorialVideo) => {
    const approved = window.confirm(copy.deleteConfirm)
    if (!approved) return
    deleteMutation.mutate(video.id)
  }

  if (isLoading) {
    return <p className="body-copy">{copy.loading}</p>
  }

  if (isError) {
    return <p className="body-copy text-danger">{copy.loadError}</p>
  }

  return (
    <div className="space-y-5">
      <SectionHeader
        title={copy.pageTitle}
        subtitle={isSaasOwner ? copy.pageSubtitleSaas : copy.pageSubtitleClinic}
        actions={
          isSaasOwner ? (
            <Button onClick={openCreateModal}>
              <Plus className="h-4 w-4" />
              {copy.newVideo}
            </Button>
          ) : undefined
        }
      />

      {isSaasOwner ? (
        <>
          <Card>
            <p className="overline">{copy.saasStatsTitle}</p>
            <div className="mt-3 grid gap-3 md:grid-cols-3">
              <div className="rounded-lg border border-slate-200 bg-slate-50 p-3">
                <p className="caption">{copy.saasTotalVideos}</p>
                <p className="mt-1 text-2xl font-bold text-night">{videos.length}</p>
              </div>
              <div className="rounded-lg border border-slate-200 bg-success/10 p-3">
                <p className="caption">{copy.saasPublishedVideos}</p>
                <p className="mt-1 text-2xl font-bold text-success">{publishedVideos}</p>
              </div>
              <div className="rounded-lg border border-slate-200 bg-amber-100/60 p-3">
                <p className="caption">{copy.saasDraftVideos}</p>
                <p className="mt-1 text-2xl font-bold text-amber-700">{draftVideos}</p>
              </div>
            </div>
            <p className="caption mt-3">{copy.reorderHint}</p>
          </Card>

          <Card>
            <div className="mb-4 flex items-center justify-between gap-3">
              <div>
                <p className="text-base font-semibold text-night">{copy.manageTitle}</p>
                <p className="caption mt-1">{copy.manageSubtitle}</p>
              </div>
              <Button variant="secondary" onClick={openCreateModal}>
                <Plus className="h-4 w-4" />
                {copy.newVideo}
              </Button>
            </div>

            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-slate-100">
                <thead className="bg-slate-50">
                  <tr>
                    <th className="px-3 py-2 text-left overline">{copy.colTitle}</th>
                    <th className="px-3 py-2 text-left overline">{copy.colThumbnail}</th>
                    <th className="px-3 py-2 text-left overline">{copy.colOrder}</th>
                    <th className="px-3 py-2 text-left overline">{copy.colStatus}</th>
                    <th className="px-3 py-2 text-left overline">{copy.colActions}</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 bg-white">
                  {saasOrderedVideos.map((video) => (
                    <tr
                      key={video.id}
                      draggable
                      onDragStart={() => setDraggedVideoId(video.id)}
                      onDragEnd={() => setDraggedVideoId(null)}
                      onDragOver={(event) => event.preventDefault()}
                      onDrop={() => handleDropVideo(video.id)}
                      className="cursor-grab active:cursor-grabbing"
                    >
                      <td className="px-3 py-3 align-top">
                        <div className="flex items-start gap-2">
                          <GripVertical className="mt-0.5 h-4 w-4 text-slate-400" />
                          <div>
                            <p className="text-sm font-semibold text-night">{video.title}</p>
                            <p className="caption mt-1 break-all">{video.youtube_url}</p>
                          </div>
                        </div>
                      </td>
                      <td className="px-3 py-3 align-top">
                        {video.thumbnail_url ? (
                          <img
                            src={video.thumbnail_url}
                            alt={video.title}
                            className="h-14 w-24 rounded-md border border-slate-200 object-cover"
                          />
                        ) : (
                          <span className="caption">{copy.noThumbnail}</span>
                        )}
                      </td>
                      <td className="px-3 py-3 text-sm text-slate-700 align-top">{video.order_index}</td>
                      <td className="px-3 py-3 align-top">
                        <Badge
                          className={
                            video.is_published
                              ? 'bg-success/15 text-success'
                              : 'bg-slate-100 text-slate-600'
                          }
                        >
                          {video.is_published ? copy.published : copy.draft}
                        </Badge>
                      </td>
                      <td className="px-3 py-3 align-top">
                        <div className="flex flex-wrap gap-2">
                          <Button size="sm" variant="secondary" onClick={() => openEditModal(video)}>
                            <Pencil className="h-3.5 w-3.5" />
                            {copy.edit}
                          </Button>
                          <Button size="sm" variant="danger" onClick={() => handleDeleteVideo(video)}>
                            <Trash2 className="h-3.5 w-3.5" />
                            {copy.delete}
                          </Button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        </>
      ) : (
        <>
          <Card>
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <p className="overline">{copy.progressTitle}</p>
                <p className="mt-2 text-2xl font-bold text-night">{summary.completion_percent.toFixed(0)}%</p>
              </div>
              <div className="flex gap-6">
                <div>
                  <p className="caption">{copy.completed}</p>
                  <p className="text-lg font-semibold text-night">
                    {summary.completed_videos}/{summary.total_videos}
                  </p>
                </div>
                <div>
                  <p className="caption">{copy.remaining}</p>
                  <p className="text-lg font-semibold text-night">{summary.remaining_videos}</p>
                </div>
              </div>
            </div>
            <div className="mt-4 h-2 w-full overflow-hidden rounded-full bg-slate-200">
              <div
                className="h-full rounded-full bg-primary transition-all"
                style={{ width: `${Math.max(0, Math.min(summary.completion_percent, 100))}%` }}
              />
            </div>
          </Card>

          <div className="grid gap-4 xl:grid-cols-5">
            <Card className="xl:col-span-2">
              <p className="text-sm font-semibold text-night">{copy.watchListTitle}</p>
              <p className="caption mt-1">{copy.watchListSubtitle}</p>

              {videos.length ? (
                <div className="mt-4 space-y-2">
                  {videos.map((video) => {
                    const selected = selectedVideoId === video.id
                    return (
                      <button
                        key={video.id}
                        type="button"
                        onClick={() => setSelectedVideoId(video.id)}
                        className={`w-full rounded-lg border px-3 py-3 text-left transition ${
                          selected
                            ? 'border-primary bg-primary/5'
                            : 'border-slate-200 hover:border-slate-300 hover:bg-slate-50'
                        }`}
                      >
                        <div className="flex items-start justify-between gap-2">
                          <p className="text-sm font-semibold text-night">{video.title}</p>
                          {video.progress_completed ? (
                            <CheckCircle2 className="h-4 w-4 text-success" />
                          ) : (
                            <Circle className="h-4 w-4 text-slate-400" />
                          )}
                        </div>
                        <div className="mt-2 flex items-center gap-2">
                          <Badge
                            className={
                              video.is_published ? 'bg-success/15 text-success' : 'bg-slate-100 text-slate-600'
                            }
                          >
                            {video.is_published ? copy.published : copy.draft}
                          </Badge>
                        </div>
                      </button>
                    )
                  })}
                </div>
              ) : (
                <div className="mt-4 rounded-lg border border-dashed border-slate-200 p-4 text-sm text-slate-500">
                  {copy.emptyList}
                </div>
              )}
            </Card>

            <Card className="xl:col-span-3">
              {selectedVideo ? (
                <div className="space-y-4">
                  <div className="overflow-hidden rounded-xl border border-slate-200 bg-black">
                    <iframe
                      title={selectedVideo.title}
                      src={selectedVideo.embed_url}
                      className="aspect-video w-full"
                      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                      allowFullScreen
                    />
                  </div>

                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <p className="text-lg font-semibold text-night">{selectedVideo.title}</p>
                      <p className="caption mt-1">
                        {copy.created}: {formatDate(selectedVideo.created_at)} • {copy.updated}:{' '}
                        {formatDate(selectedVideo.updated_at)}
                      </p>
                    </div>
                    <Button
                      type="button"
                      variant={selectedVideo.progress_completed ? 'secondary' : 'primary'}
                      onClick={() =>
                        progressMutation.mutate({
                          videoId: selectedVideo.id,
                          completed: !selectedVideo.progress_completed,
                        })
                      }
                      disabled={progressMutation.isPending}
                    >
                      {selectedVideo.progress_completed ? copy.markIncomplete : copy.markComplete}
                    </Button>
                  </div>

                  <p className="text-sm leading-relaxed text-slate-600 break-words whitespace-pre-wrap">
                    {selectedVideo.description || copy.noDescription}
                  </p>
                </div>
              ) : (
                <div className="flex min-h-[240px] items-center justify-center rounded-xl border border-dashed border-slate-200 text-sm text-slate-500">
                  {copy.noVideoSelected}
                </div>
              )}
            </Card>
          </div>
        </>
      )}

      <Modal
        isOpen={isModalOpen}
        onClose={() => {
          setIsModalOpen(false)
          setEditingVideo(null)
        }}
        title={editingVideo ? copy.modalEditTitle : copy.modalCreateTitle}
      >
        <form className="space-y-4" onSubmit={handleSaveVideo}>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">{copy.fieldTitle}</label>
            <Input
              value={form.title}
              onChange={(event) => setForm((prev) => ({ ...prev, title: event.target.value }))}
              placeholder={copy.placeholderTitle}
            />
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">{copy.fieldDescription}</label>
            <TextArea
              rows={3}
              value={form.description}
              onChange={(event) => setForm((prev) => ({ ...prev, description: event.target.value }))}
              placeholder={copy.placeholderDescription}
            />
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">{copy.fieldYoutubeUrl}</label>
            <Input
              value={form.youtube_url}
              onChange={(event) => setForm((prev) => ({ ...prev, youtube_url: event.target.value }))}
              placeholder={copy.placeholderYoutube}
            />
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">{copy.fieldThumbnailPreview}</label>
            {form.thumbnail_url ? (
              <img
                src={form.thumbnail_url}
                alt={copy.fieldThumbnailPreview}
                className="h-28 w-full rounded-lg border border-slate-200 object-cover"
              />
            ) : (
              <div className="flex h-28 items-center justify-center rounded-lg border border-dashed border-slate-200 bg-slate-50 text-sm text-slate-500">
                {copy.noThumbnail}
              </div>
            )}
            <p className="caption mt-1">{copy.fieldThumbnailAutoHint}</p>
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">{copy.fieldOrder}</label>
            <Input
              type="number"
              min={1}
              value={form.order_index}
              onChange={(event) => setForm((prev) => ({ ...prev, order_index: event.target.value }))}
            />
          </div>

          <label className="flex items-center gap-2 text-sm text-slate-700">
            <input
              type="checkbox"
              checked={form.is_published}
              onChange={(event) => setForm((prev) => ({ ...prev, is_published: event.target.checked }))}
            />
            {copy.fieldPublished}
          </label>

          <div className="flex justify-end gap-2 pt-2">
            <Button
              type="button"
              variant="secondary"
              onClick={() => {
                setIsModalOpen(false)
                setEditingVideo(null)
              }}
            >
              {copy.cancel}
            </Button>
            <Button type="submit" disabled={saveMutation.isPending}>
              {saveMutation.isPending ? copy.saving : copy.save}
            </Button>
          </div>
        </form>
      </Modal>
    </div>
  )
}
